+++
title = 'API Gripe'
date = 2025-10-05T15:06:38+01:00
draft = true
tags = ['api', 'rant']
+++
I promised myself I wouldn't post too often with rants about random stuff I come across, and I like to think I've done okay so far (even though some companies _cough_ Microsoft _cough_ give me ample opportunity).

But one thing I've come across a number of times over the years, and again recently, is how some people handle errors in their APIs.

## Don't trigger the crazy person

I'm not talking about people using a 400 response when maybe it should have been a 412, those might need discussion, but at least when I'm consuming the API, I know _something_ is wrong. No, I'm talking about people who wrap up their errors in a success response!

You create your client code, you put in your handlers for determining if the response was successful or not and handling error scenarios. You run the code, and it works perfectly, but you don't get the result you were expecting. What do you do? Well, you start adding more logging. Maybe the logic is wrong, maybe the wrong endpoint was called. Eventually you dump out the API response, or fire up something like [Fiddler](https://www.telerik.com/fiddler) and you stare in horror at the response you're getting. Something like this.

```text
GET https://api.example.com/v1/users/1234567890
Accept: application/json

---

HTTP/1.1 200 OK
Content-Type: application/json

{
  "error": "User not found
}
```

![OMG WHY](creepy-smile.gif)

Or my personal favourite, where the error in the body also includes the status code that it should have returned.

As a developer, what do you do with this heinous response? Well, you start to cry and wonder if maybe your parents were right when they told you that monsters are real. Then you start to write parsers to handle this, you check the response for "error" responses and handle them differently. You have to start looking at the response content to work out if something isn't found or if an argument is invalid. You start to think that maybe living in a forest for the rest of your days is a better option. Or maybe you start to think of "creative" ways that the original programmer could be taught a valuable lesson in considering their customers.

I've seen this way too often now, and from sources I didn't expect to see it from (maybe their name rhymes with "biro-loft"), and each time it just hurts a little more. This isn't a post on how this could be made better, as there are already standards for this, this is me just needing to get this off my chest.

If you're building an API, then please, for the love of caffeine, please don't do this.
