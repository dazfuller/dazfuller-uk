+++
title = 'Unit Test Coverage'
date = 2025-05-03T15:44:02+01:00
tags = ['dotnet', 'testing']
featured_image = 'coverage-results.webp'
+++
It comes up at least a couple of times a year and has done for as long as I can remember. It brings with it uncertainty, fear, anxiety, and sometimes raised voices. It can end forge bonds, break friendships, and could tear our society apart (okay, maybe not quite).

It is... ___Code Coverage___!!

I am, and have been for a while, a big fan of the teachings of Testivus which I've included later on in this post. But there are additional teachings which are available [online](http://www.agitar.com/downloads/TheWayOfTestivus.pdf) and are definitely worth a read.

## The issue

Code coverage is a contentious issue, as are most things testing related in the world of software development. Don't believe me? Have a look around for opinions on Test-Driven development (TDD), the difference between unit and integration testing, or how quickly your tests should run.

Everyone has an opinion, even me. So I'm going to be clear. These are my opinions and are not hard and fast rules. I find they work for me and a lot of people who I've mentored, but it might not work for you. The important thing is to find a way that does, and when you do then share it with people, because it might help them as well. Just don't be dogmatic about it.

![Everyone is a genius](einstein-genius.webp)

And so, on to my opinions.

## Lines are not intention

The largest issue I tend to see is when people are pushed to achieve higher levels of code coverage by measuring it in lines. Line coverage (and branch coverage) is a great way of making sure your tests are reaching as much of your code base as possible. Even if you take this to the extreme of 100% coverage, it doesn't make the tests any good.

I ran a training session once where I put up a simple method which added two values together, and then a test which showed that the method produced the correct results. I asked everybody if they thought this meant I had written enough tests.

It was a fun moment. You could see everyone wanted to say yes, but they knew they were walking into a trap.

The answer was no, it wasn't enough testing. Let me show you why with a different example.

Here we have a method which takes a string input and returns the count of all the characters in the string.

```csharp
public static class TextChecker
{
    public static Dictionary<char, int> GetCharCount(string text)
    {
        var characters = Enumerable.Range('a', 'z').ToDictionary(c => (char)c, c => 0);

        foreach (var c in text)
        {
            if (char.IsAsciiLetter(c))
            {
                characters[c]++;
            }
        }
        
        return characters;
    }
}
```

Next, we have a test, which passes in a string and checks to make sure that the character count produced is correct.

```csharp
public class TextCheckerTests
{
    [Fact]
    public void GetCharCount_ReturnsCorrectCount()
    {
        // Arrange
        var expected = new Dictionary<char, int>
        {
            ['h'] = 1,
            ['e'] = 1,
            ['l'] = 2,
            ['o'] = 1
        };
        
        // Act
        var actual = TextChecker.GetCharCount("hello");
        
        // Assert
        
        // Check that all expected values are present in the result
        foreach (var (key, value) in expected)
        {
            Assert.Equal(value, actual[key]);
        }

        // Check that all values in the result which are not expected are 0
        foreach (var (k, vi) in actual)
        {
            if (!expected.ContainsKey(k))
            {
                Assert.Equal(0, vi);
            }
        }
    }
}
```

If I run the test against the code then I get 100% coverage. But the test is not covering my intention here, as in it's not testing what I want the method to actually achieve.

Let's add a new test to see what I mean.

```csharp
[Fact]
public void GetCharCount_MixedCase_ReturnsCorrectCount()
{
    // Arrange
    var expected = new Dictionary<char, int>
    {
        ['h'] = 1,
        ['e'] = 1,
        ['l'] = 2,
        ['o'] = 1
    };
    
    // Act
    var actual = TextChecker.GetCharCount("Hello");
    
    // Assert
    
    // Check that all expected values are present in the result
    foreach (var (key, value) in expected)
    {
        Assert.Equal(value, actual[key]);
    }
}
```

Running the tests now, you get the following issue:

```text
The given key 'H' was not present in the dictionary
```

Despite the 100% coverage, the code doesn't work the way we want it to. In the training session I ran showed something similar by adding together two very large numbers which overflowed and resulted in a negative value being returned.

## My approach

The way in which I approach tests is like this:

1. Write the tests that prove the method works in the way I expect it to work
2. Check the line and branch coverage
3. Extend my tests to make sure I cover as much of the code as possible

By "as much of the code as possible" I mean, if I'm checking an argument for null and throwing an error if it is, then write a test to make sure it works. If I have a switch statement, then make sure I'm testing each branch of it.

Things I will seldom do, though, are things like checking for disk failure if I'm reading a file. I know I need to handle the issue if it arises, but mocking out disk activity doesn't add a lot of value for the time needed to implement it. And I don't often test web requests if I'm using the standard `HttpClient` (though, using [Refit](https://github.com/reactiveui/refit) means you can if you want to).

### As an indicator

Reporting line and branch coverage is useful to serve as an indicator when reviewing code. If the coverage is low, then it's worth checking the tests which have been written to see if they're testing enough. If the code coverage drops significantly, then it could be that the new code isn't being checked. It becomes a tool letting you know that maybe you should check something before approving but, in my opinion, it is not a reason to reject a review in itself.

As with any indicator or review process, it's something which you learn and improve with over time. If you're just starting out in your career, then building working code is more important, chasing code coverage just becomes demoralising.

## Testivus on Test Coverage

This is taken from a [thread](https://www.artima.com/forums/flat.jsp?forum=106&thread=204677) on Artima, I always lose it, so I'm adding it here as well for posterity.

> Early one morning, a programmer asked the great master:
> 
> _“I am ready to write some unit tests. What code coverage should I aim for?”_
> 
> The great master replied:
> 
> _“Don’t worry about coverage, just write some good tests.”_
> 
> The programmer smiled, bowed, and left.
> 
> Later that day, a second programmer asked the same question. The great master pointed at a pot of boiling water and said:
> 
> _“How many grains of rice should put in that pot?”_
> 
> The programmer, looking puzzled, replied:
> 
> _“How can I possibly tell you? It depends on how many people you need to feed, how hungry they are, what other food you are serving, how much rice you have available, and so on.”_
> 
> _“Exactly,”_ said the great master.
> 
> The second programmer smiled, bowed, and left.
> 
> Toward the end of the day, a third programmer came and asked the same question about code coverage.
> 
> _“Eighty percent and no less!”_ Replied the master in a stern voice, pounding his fist on the table.
> 
> The third programmer smiled, bowed, and left.
> 
> After this last reply, a young apprentice approached the great master:
> 
> _“Great master, today I overheard you answer the same question about code coverage with three different answers. Why?”_
> 
> The great master stood up from his chair:
> 
> _“Come get some fresh tea with me and let’s talk about it.”_
> 
> After they filled their cups with smoking hot green tea, the great master began to answer:
> 
> _“The first programmer is new and just getting started with testing. Right now he has a lot of code and no tests. He has a long way to go; focusing on code coverage at this time would be depressing and quite useless. He’s better off just getting used to writing and running some tests. He can worry about coverage later.”_
> 
> _“The second programmer, on the other hand, is quite experienced both at programming and testing. When I replied by asking her how many grains of rice I should put in a pot, I helped her realize that the amount of testing necessary depends on a number of factors, and she knows those factors better than I do – it’s her code after all. There is no single, simple, answer, and she’s smart enough to handle the truth and work with that.”_
> 
> _“I see,”_ said the young apprentice, _“but if there is no single simple answer, then why did you answer the third programmer ‘Eighty percent and no less’?”_
> 
> The great master laughed so hard and loud that his belly, evidence that he drank more than just green tea, flopped up and down.
> 
> _“The third programmer wants only simple answers – even when there are no simple answers … and then does not follow them anyway.”_
> 
> The young apprentice and the grizzled great master finished drinking their tea in contemplative silence.
