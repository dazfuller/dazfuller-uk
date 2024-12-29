+++
title = 'Advent of Code 2024 - Day 11'
date = 2024-12-28T10:56:55Z
draft = true
tags = ['golang', 'aoc']
featured_image = 'snowy.png'
+++
I participated in [Advent of Code](https://adventofcode.com) again this year, but unlike previous years I actually put some time into it. Previous years I've started, gotten immediately distracted, and then stopped. This year I made it to day 20 before getting distracted.

[Day 11](https://adventofcode.com/2024/day/11) though I wanted to do a write-up on as it needed as much effort in the reading as the implementation.

## Plutonian Pebbles

The short version of the challenge is this. There are a set of stones in front of you, each time you blink they change based on the number engraved on them and a set of rules depending on the number.

> * If the stone is engraved with the number 0, it is replaced by a stone engraved with the number 1.
> * If the stone is engraved with a number that has an even number of digits, it is replaced by two stones. The left half of the digits are engraved on the new left stone, and the right half of the digits are engraved on the new right stone. (The new numbers don't keep extra leading zeroes: 1000 would become stones 10 and 0.)
> * If none of the other rules apply, the stone is replaced by a new stone; the old stone's number multiplied by 2024 is engraved on the new stone.

There's also a paragraph that reads as this.

> No matter how the stones change, their order is preserved, and they stay on their perfectly straight line.

The first part of the challenge is to work out how many stones, based on the input, you would have after 25 blinks.

## Attempt number 1

The way I always start is to put together a solution which matches the rules and works on the example provided in the description before moving on to the actual input. Reading the above it looks as though we're dealing with an array which will need updates and insertions. If we start with a sample input of `24 0 130` then on the first blink the number 24 would be replaced with 2 stones (because it's even) which would be 2 and 4. 0 would become 1, and finally 130 would become 263120 as it falls into the last rule. So, 5 blinks would give us this:

```text
Start  : 24 0 130
Blink 1: 2 4 1 263120
Blink 2: 4048 8096 2024 253 120
Blink 3: 40 48 80 96 20 24 512072 242880
Blink 4: 4 0 4 8 8 0 9 6 20 24 512 72 242 880
Blink 5: 8096 1 8096 16192 16192 1 18216 12144 2 0 2 4 1036288 7 2 453376 1781120
```

We started with 3 stones and after 5 blinks we have 17 stones. Following these rules we can keep inserting and replacing values, and for the example input it works fine.

Lets start with a simple approach which iterates 25 times, and then checks each stone and updates the list of stones based on the rules. This time using the sample input provided in the problem itself.

```go
package main

import (
	"fmt"
	"math"
	"slices"
	"strconv"
	"time"
)

func main() {
	input := []int{125, 17}

	start := time.Now()

	for blink := 0; blink < 25; blink++ {
		for i := 0; i < len(input); i++ {
			if input[i] == 0 {
				input[i] = 1
			} else if numDigits(input[i])%2 == 0 {
				s1, s2 := splitNumber(input[i])
				input[i] = s2
				input = slices.Insert(input, i, s1)
				i++
			} else {
				input[i] *= 2024
			}
		}
		fmt.Printf("After %d blinks we have %d stones\n", blink+1, len(input))
	}

	fmt.Printf("Time taken: %v\n", time.Since(start))
}

func numDigits(i int) int {
	return int(math.Floor(math.Log10(float64(i)) + 1))
}

func splitNumber(i int) (int, int) {
	asString := strconv.Itoa(i)

	aPart := asString[:len(asString)/2]
	bPart := asString[len(asString)/2:]

	a, _ := strconv.Atoi(aPart)
	b, _ := strconv.Atoi(bPart)

	return a, b
}
```

Running against the example input this takes 86ms to execute, against the full input it takes just over 1 second to execute. If you execute the code though you'll see that most of the time taken is on executing the 25th iteration.

Now, having done this, I know that the next part will be to perform the same over many more iterations. So lets crank this up to 30 blinks and see how long it takes to run for the full input, or if you'd rather not wait, let me do it for you.

And the time is...

1 minute 6 seconds.

So we've gone from 1 second, to 1 minute by adding 5 more iterations. And the puzzle requires us to go much higher than this.

This tells us one thing, that our array with inserts is not going to be our solution, unless we're willing to wait for a very long time for the result. But what can we do?

## Rethinking the solution

This is going to take forever to run, but what can we do?

There's a couple of places of concern in the code. The first is our code to split a number into two as it's doing a lot of string conversions. There is a mathematical way of doing this though, so lets change that.

```go
func splitNumber(n int) (int, int) {
	length := float64(numDigits(n))

	n1 := float64(n)
	x := math.Floor(n1 / math.Pow(10, length/2))
	y := n1 - x*math.Pow(10, length/2)

	return int(x), int(y)
}
```

If I change the number of iterations to 26 then with the existing code it takes 2.26 seconds. This change to splitNumber takes it to... 2.26 seconds!!

Okay, well we're doing less string manipulation now, and at larger scale this will probably help, but right now it's not helping out.

What else is there?

The next candidate is the `slices.Insert` code, this method is `O(len(s) + len(v))`. So the larger our array grows the longer this is going to take to run, but how can we get around this? We need the insert because we need to keep the pebbles in order.

Don't we?

Wait...

There's no part of our code which is dependent on the order of the pebbles, except for the part we introduced using the insert method. Why are we tracking the order then? Well, because of this:

> No matter how the stones change, their order is preserved, and they stay on their perfectly straight line.

But, we don't need the order for the rules, so why is this there?

Well, it makes a nice story it seems.

Okay, if we don't need to keep an eye on the order of the pebbles, then what can we do instead?

We need to work out how many pebbles there after _n_ blinks, not what order they're in. And looking at the above output there are instances where we're dealing with numbers like 4048 and 8096 a few times in the same iteration, but we know after the first one that these two numbers will produce 2 new pebbles with the same count.

So why don't we track how many of each numbered pebble we have instead? We can do this using a hash map with the pebble number as a key, and how many of them we have after each blink. We also don't care about previous iterations, just what we have after each blink.

Lets have a go at putting this together based on the sample input.

## Attempt 2

We're going to need to read in our initial state to create our map and initialise the their count. That's going to look something like this:

```go
pebbles := make(map[int]int)

for _, v := range input {
    pebbles[v]++
}
```

That gives us our map of initial values and handles cases where the same value might be in the input more than once.

Now on each iteration we're going to build a new map to hold the changed values. If we get a pebble like 4048 and we've counted 2 of them, then we know from the rules that it gets split into 40 and 48, so there will be two of each of them as well.

Before we start though, I changed the original code so it captures how long each iteration takes, and then executed for 32 iterations based on the example input.

```text
After 1 blinks we have 3 stones: 23.458µs
After 2 blinks we have 4 stones: 1.042µs
After 3 blinks we have 5 stones: 833ns
After 4 blinks we have 9 stones: 2.417µs
After 5 blinks we have 13 stones: 1µs
After 6 blinks we have 22 stones: 5.083µs
After 7 blinks we have 31 stones: 2.875µs
After 8 blinks we have 42 stones: 4µs
After 9 blinks we have 68 stones: 9.083µs
After 10 blinks we have 109 stones: 8.666µs
After 11 blinks we have 170 stones: 13.375µs
After 12 blinks we have 235 stones: 16µs
After 13 blinks we have 342 stones: 32.458µs
After 14 blinks we have 557 stones: 50.458µs
After 15 blinks we have 853 stones: 82.666µs
After 16 blinks we have 1298 stones: 132.625µs
After 17 blinks we have 1951 stones: 236.709µs
After 18 blinks we have 2869 stones: 428.875µs
After 19 blinks we have 4490 stones: 868.792µs
After 20 blinks we have 6837 stones: 1.729125ms
After 21 blinks we have 10362 stones: 3.332625ms
After 22 blinks we have 15754 stones: 6.293541ms
After 23 blinks we have 23435 stones: 11.081666ms
After 24 blinks we have 36359 stones: 23.677209ms
After 25 blinks we have 55312 stones: 44.894292ms
After 26 blinks we have 83230 stones: 94.796792ms
After 27 blinks we have 127262 stones: 222.503083ms
After 28 blinks we have 191468 stones: 513.269417ms
After 29 blinks we have 292947 stones: 1.208440792s
After 30 blinks we have 445882 stones: 2.762093958s
After 31 blinks we have 672851 stones: 6.363123417s
After 32 blinks we have 1028709 stones: 14.808837625s
Time taken: 26.066252125s
```

We can use this and compare it with the new solution then to see how it changes overall, and per iteration.

Right, lets change our code.

```go
package main

import (
	"fmt"
	"math"
	"time"
)

func main() {
	input := []int{125, 17}

	start := time.Now()

	pebbles := make(map[int]int)

	for _, v := range input {
		pebbles[v]++
	}

	for blink := 0; blink < 6; blink++ {
		blinkStart := time.Now()
		// Create a new map to hold the number of pebbles for the current iteration
		updatedPebbles := make(map[int]int)

		for pebble, currentCount := range pebbles {
			if pebble == 0 {
				// If the pebble is engraved with 0 then it becomes 1
				updatedPebbles[1] += currentCount
			} else if numDigits(pebble)%2 == 0 {
				// If the number of digits engraved on the pebble is even, then its number is split into two
				p1, p2 := splitNumber(pebble)
				updatedPebbles[p1] += currentCount
				updatedPebbles[p2] += currentCount
			} else {
				// Otherwise the number on the pebble is multiplied by 2024
				updatedPebbles[pebble*2024] += currentCount
			}
		}

		// Discard the previous iteration
		pebbles = updatedPebbles

		blinkDuration := time.Since(blinkStart)
		fmt.Printf("After %d blinks we have %d stones: %v\n", blink+1, countPebbles(pebbles), blinkDuration)
	}

	fmt.Printf("Time taken: %v\n", time.Since(start))
}

// countPebbles calculates the total count of pebbles in the provided map by summing all values
func countPebbles(pebbles map[int]int) int {
	count := 0
	for _, v := range pebbles {
		count += v
	}
	return count
}

func numDigits(i int) int {
	return int(math.Floor(math.Log10(float64(i)) + 1))
}

func splitNumber(n int) (int, int) {
	length := float64(numDigits(n))

	n1 := float64(n)
	x := math.Floor(n1 / math.Pow(10, length/2))
	y := n1 - x*math.Pow(10, length/2)

	return int(x), int(y)
}
```

I ran a check on this based on the example input and we still end up with 22 stones after each 6 blinks, so lets run it for the 32 iterations the same as above and see what we get.

```text
After 1 blinks we have 3 stones: 13.5µs
After 2 blinks we have 4 stones: 791ns
After 3 blinks we have 5 stones: 500ns
After 4 blinks we have 9 stones: 833ns
After 5 blinks we have 13 stones: 3.667µs
After 6 blinks we have 22 stones: 2.292µs
After 7 blinks we have 31 stones: 2.041µs
After 8 blinks we have 42 stones: 2.458µs
After 9 blinks we have 68 stones: 3.541µs
After 10 blinks we have 109 stones: 5.041µs
After 11 blinks we have 170 stones: 5.541µs
After 12 blinks we have 235 stones: 5.084µs
After 13 blinks we have 342 stones: 5.625µs
After 14 blinks we have 557 stones: 9.875µs
After 15 blinks we have 853 stones: 8.416µs
After 16 blinks we have 1298 stones: 7.75µs
After 17 blinks we have 1951 stones: 6.667µs
After 18 blinks we have 2869 stones: 9.292µs
After 19 blinks we have 4490 stones: 8.792µs
After 20 blinks we have 6837 stones: 8.125µs
After 21 blinks we have 10362 stones: 10.083µs
After 22 blinks we have 15754 stones: 9.417µs
After 23 blinks we have 23435 stones: 10.875µs
After 24 blinks we have 36359 stones: 7.458µs
After 25 blinks we have 55312 stones: 8.083µs
After 26 blinks we have 83230 stones: 8.25µs
After 27 blinks we have 127262 stones: 9.333µs
After 28 blinks we have 191468 stones: 7.25µs
After 29 blinks we have 292947 stones: 8.417µs
After 30 blinks we have 445882 stones: 9.375µs
After 31 blinks we have 672851 stones: 7.458µs
After 32 blinks we have 1028709 stones: 7.25µs
Time taken: 301.791µs
```

We're still getting the same number of stones, but the time per iteration is much lower. It's still getting higher for each execution, but those numbers are tiny.

Lets say we want to run this for 100 blinks. Lets see how long that would take now (I removed the per iteration numbers because that might be getting a bit long).

```text
Total pebbles: 2266558877486382721
Time taken: 741.042µs
```

Our first attempte probably would have taken us to the heat death of the universe to complete, but our updated code is 741 microseconds, or 0.000741 seconds.

Incidentally, I re-ran this with the original number splitting code using strings, and the time goes up to 1.8ms or basically over twice as long, though still under 1 second.

## Job done

I'm not going to claim that this is the worlds fastest code or best implementation. I'm sure there will be plenty of other implementations out there which improve over this one. But this goes to show how sometimes over-reading the requirements can lead you down a sub-optimal route.

So, if something doesn't seem right, then question it.