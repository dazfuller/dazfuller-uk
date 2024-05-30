+++
title = 'Azure Costs CLI tool - Adding a Spark'
date = 2024-05-30T10:07:48+01:00
draft = true
tags = ['open source', 'golang', 'azure']
featured_image = 'azcosts-sparklines-banner.webp'
+++
I've had a few days off lately, so thought I'd spend some time adding some new features to the [Azure Costs](/projects/azcosts) CLI tool I've been writing and using.

## Quick recap

I wrote the CLI tool as a quick and easy way for me to collect and monitor spend in Azure at a resource group level (I'm planning on going to resource level next, but that's a future update). Importantly I wanted to maintain the collected data so I could analyze it later, and so that I could produce outputs showing me how spend has changed month-on-month.

I wrote it using [Go](https://go.dev) because I wanted to use a different language. I spend most of my work time writing code using C# or Python, and sometimes in Scala, plus a bunch of scripting languages, so I wanted something different for a personal project.

One of my team took an early Python prototype I did and this project and created an [Azure Function](https://learn.microsoft.com/azure/azure-functions/functions-overview) app which sends out an email every Sunday with the last 3 months of spend data. So it's nice that this inspired something so useful already :heart_eyes:.

## So what's new?

When I started I had collected the previous couple of months of data and the latest month and things were pretty easy to see, but after a couple more months being able to visualise the changes just from a wall of numbers was getting more difficult.

I could have added a chart to sheet but with the number of resource groups we have it would be just as difficult to visualise. So, I decided to add spark lines.

### Spark lines?

Spark lines are basically simple little charts which you put inline with the data. They're useful for visualising trends on a row-by-row basis, letting people quickly scan data looking for trends their interested in (such as spikes or upwards trends) so that they can look at the data they're interested in instead of hunting it down.