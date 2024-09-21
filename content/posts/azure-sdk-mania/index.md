+++
title = 'Azure Sdk Mania'
date = 2024-09-21T12:08:00+01:00
draft = true
tags = ['azure', 'sdk']
featured_image = 'ackbar.jpg'
+++
Lately I've been working on an application which does some very cool stuff with Microsoft [Purview](https://learn.microsoft.com/purview/). I'll go into what it does in another post, but for now I want to talk about the one thing which has been the biggest pain for this process. SDKs!

## The SDK Trap

SDKs exist to do one thing, to allow developers with work with a 3rd party system using language specific methods and types. The SDK takes care of connectivity, authentication, generating the right body, retry attempts (hopefully) and more. And when they work they are brilliant. The [Azure.Identity](https://github.com/Azure/azure-sdk-for-net/blob/main/sdk/identity/Azure.Identity/README.md) SDK is a great example of an SDK which does what it needs to well. But there are others, luring you in with the promise of simple integration, and once you've fallen into their web they will suck you dry of time and sanity.

But, I'm being overly dramatic right? Well, no. Both myself and [Richard Conway](https://www.linkedin.com/in/richardelastacloud/) have done talks before on the Microsoft SDKs and all of the pain we've gone through with them. We've covered poor documentation, use of outdated APIs, outdated SDKs themselves, and even one crazy scenario where the SDK hid an error leaving the developer in the dark with how to fix it.

Call me old-fashioned, but if an SDK needs you break out tools like [Fiddler](https://www.telerik.com/fiddler) to inspect the API requests and responses to see why it's not working, then it's not doing a great job.

Microsoft changed their SDK development process a while ago, so that they're now generated from the API docs for all target languages. Which sounds like a good idea, but somewhat falls apart at times with making sense of the SDKs themselves, or (even better) when the API docs themselves are wrong.

There have been a lot of times where I've either given up with the SDK or just not bothered to start with, and gone straight to the API. It needs a bit more thinking about, but it's often proven to be the more sane choice.

## So what happened this time?

As I mentioned at the start I've been working with [Purview](https://learn.microsoft.com/purview/) which is a collection of tools around data governance, security, and compliance. And we decided to use the SDK (queue the sad trombone soundbite).

![Disappointed](disappointed.webp)

So, first issue was that an entire package had been deprecated and replaced with a new one. Not unusual, except when the docs are all referencing the old one (sigh). So, switch to the new one, but as all the docs talk about the old SDK we're now in a position of having no documentation.

One of the first things we wanted to do was to find assets of a certain type in data map. Eventually we traced down the method needed to the `Discovery.QueryAsync` method which takes a `RequestContent` object which... just creates an HTTP request content object based on some input.

So, umm, what do we need to give it? Because, no docs. So, umm, yeah.

BREAK OUT THE BROWSER DEV TOOLS.

Yep. We ended up doing a search in the Purview web app, inspecting the query request it makes, and then creating an anonymous object in the code to match it. A complete faff, but it worked and we managed to get a... shit, it's an `Azure.Core.Response` object, so we had to extract the content back manually. More messing around but it worked finally.

We keep going through this, working out what's needed for API calls, and using it to find which methods we need to use. It's a slow process but we get it working until...

![Screaming](screaming.webp)

We use one of the methods and it just doesn't work!

We go through the same process and the web app works fine, but the SDK method just isn't doing it.

Then, we spot something.

Something horrific.

Something which you just can't make up.

The web app isn't using the new API endpoint. It's using, the old one!

That's right, the new API is just _broken_, so badly broken that even the Purview web app isn't using it. So what to do? Do we move back to the deprecated package? Well, we could, but building something new on something deprecated just doesn't sit right, and we'd need to change everything we've got so far. So, back to the ever present plan B, we create a new client just for this which uses the APIs directly.

## This is Madness

These SDKs just aren't useful, in fact they're worse than that, they're a time-suck. They prey on unsuspecting developers and derail sprints, sending those developers on goose chases with the promise of simplicity.

I want them to work. They should work. They should provide a stable interface to allow developers to build solutions around Microsoft's products. But this just keeps happening and kills any kind of productivity. So, when you start looking at that next project, by all means try the SDK, but have a backup plan for going to the API, and make sure you pay attention to how much time you're wasting and know when to just stop.
