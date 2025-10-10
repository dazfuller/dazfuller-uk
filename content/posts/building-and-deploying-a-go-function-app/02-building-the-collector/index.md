+++
title = 'Go Function App: Building the Collector'
date = 2025-08-18T15:36:56+01:00
tags = ['Golang', 'Azure', 'FunctionApp', 'SQL']
draft = true
series = ['Building and Deploying a Go Function App']
series_order = 2
+++
In the [first part]({{< ref "/posts/building-and-deploying-a-go-function-app/01-creating-the-resources" >}} "Creating the resources") of this series I went through the creation of the resources needed for this project. In this part we'll dive into creating the part of the application which retrieves the news items from the API and then writes them to our vector store.

To do this we're going to need to build a couple of things. First of all we need to configure our vector store which, in this case, is an [Azure SQL Database](https://learn.microsoft.com/azure/azure-sql/database/sql-database-paas-overview) making use of the [Vector data type](https://learn.microsoft.com/sql/t-sql/data-types/vector-data-type "SQL Vector Data Type"). There's a few features which are still on the way, but with this data type and the [VECTOR_DISTANCE](https://learn.microsoft.com/sql/t-sql/functions/vector-distance-transact-sql) function, we have all we need.

And yes, I did write that in all caps.

![SQL Developers be like...](sql-devs.webp "SQL Developers be like...")

Okay, let's get started.

## The data source

We're going to collect data from the [News API](https://newsapi.org/), if you want to follow along with the series you'll need to sign up to get an API key. Developer licensing is free but if we you use this in a production environment you'll need to get a paid subscription. If you're only just doing this now then you might need to re-run the infrastructure scripts to ensure that the API key has been added to the key vault.

Once we have the API we can try out a couple of requests to see what we get. This took me a few attempts as I wanted to load just news for the UK, but even though there's a country parameter you can provide, the only valid value is "us" (because nothing news worth happens outside of America?).

Be careful with how many requests you make, the free tier is limited to 100 per day (50 every 12 hours). After that you get rate limited.

Anyway, let's have a look at an example request. I'm going to use curl to do this with `jq` to format the response, but you could use Postman, Httpie, Nushell, or whichever tool you prefer.

```bash
# In NuShell, so you might want to change how you use the environment variable for other shells
> curl -H $"X-Api-Key: ($env.NEWS_API_KEY)" https://newsapi.org/v2/top-headlines?sources=bbc-news,independent,mtv-news-uk&page_size=3 | jq .
```

Yep, I'm using an environment variable for the API key, not gonna tell you all my secrets :wink:.

Running this we get a response which looks like the following (truncated, and the headlines you see will of course differ).

```json
{
  "status": "ok",
  "totalResults": 24,
  "articles": [
    {
      "source": {
        "id": "bbc-news",
        "name": "BBC News"
      },
      "author": "BBC News",
      "title": "James Bond should be a man, says Dame Helen Mirren",
      "description": "The Oscar-winning actor says that the famous 007 character can't be a woman as it \"just doesn't work\".",
      "url": "https://www.bbc.co.uk/news/articles/c1jnen9zklpo",
      "urlToImage": "https://ichef.bbci.co.uk/ace/branded_news/1200/cpsprodpb/43a4/live/6f7604d0-7bc3-11f0-9ba0-cb1cdc075b66.jpg",
      "publishedAt": "2025-08-18T02:07:16.4745069Z",
      "content": "Mirren has previously been quoted saying that the concept of James Bond was \"born out of profound sexism\", and that women have always been an \"incredibly important part\" of the Secret Service. \r\nMirr… [+342 chars]"
    },
    {
      "source": {
        "id": "bbc-news",
        "name": "BBC News"
      },
      "author": "BBC News",
      "title": "Methanol poisoning: Man saw kaleidoscopic light before going blind",
      "description": "Calum Macdonald and the families of three people who died in South East Asia call on the Foreign Office for clearer travel advice.",
      "url": "https://www.bbc.co.uk/news/articles/czd0qlmjl05o",
      "urlToImage": "https://ichef.bbci.co.uk/ace/branded_news/1200/cpsprodpb/d2cb/live/b07e24e0-7b81-11f0-ab3e-bd52082cd0ae.jpg",
      "publishedAt": "2025-08-18T05:37:21.2561947Z",
      "content": "Methanol is a type of alcohol commonly found in cleaning products, fuel and antifreeze. It is similar to ethanol, which is used for alcoholic drinks, but is more toxic to humans because of the way it… [+925 chars]"
    }]
}
```

We get a status and the number of articles returned. Each article shows its source and the expected metadata, a couple of links, and some content. The actual content itself is truncated so doesn't really help us in what we're trying to achieve, as the couple of sentences might be useful, or might just be meaningless in the context of the news article.

The articles don't have a common identity value, so we'll need to define one. To do this we're going to use the `url` value, as there shouldn't be multiple articles pointing to the same URL.

Otherwise, it's a decent response with no weird formatting going on. Often you can see non-standard timestamps, but here we get a proper [RFC3339](https://www.rfc-editor.org/rfc/rfc3339) value.

## Vector store

In the previous post we used Terraform to deploy our database script. As noted then this isn't the best way of doing it and ideally we should be using something like a SQL database project and the [sqlpackage](https://learn.microsoft.com/sql/tools/sqlpackage/sqlpackage-download) command line tool to deploy. I might very well do that in a future post, but it was good enough for now.

Let's have a look at the script again.

```sql
IF OBJECT_ID('article', 'U') IS NULL
BEGIN
    CREATE TABLE article
    (
        [SourceId]              NVARCHAR(100) NOT NULL
        , [SourceName]          NVARCHAR(100) NOT NULL
        , [Author]              NVARCHAR(255) NULL
        , [Title]               NVARCHAR(255) NOT NULL
        , [Description]         NVARCHAR(1000) NOT NULL
        , [Url]                 NVARCHAR(255) NOT NULL
        , [ImageUrl]            NVARCHAR(255) NOT NULL
        , [PublishedAt]         DATETIMEOFFSET NOT NULL
        , [Content]             NVARCHAR(MAX) NOT NULL
        , [DescriptionVector]   VECTOR(1536) NULL

        , CONSTRAINT [PK_article] PRIMARY KEY CLUSTERED ([Url] ASC)
    )
END
GO
```

You can see here that we're saving a number of items from the API response, but we also have a `DescriptionVector` column. This is where we will be saving the vector representation of the article. We've set the size to `1536` as we'll be using the text-embedding-3-small model and that's the size of the vector representation it will return.

You'll have noticed that the API response does not give us the full article, so we'll be searching over the snippet. If you want to try and extend this project, one way you could do this is to use the collected URL to retrieve the full article. Just make sure if you do so then you remain compliant with local legislation and be respectful of the distributor's services (don't DDOS them!). I would always link to the source post as well in any response. Generating responses to questions is cool, but depriving websites of click-through traffic is _not_.

## Building the collector

Okay, let's put this into some practice and build the collector. We want to regularly collect new articles (without throttling ourselves), so we are going to use a [timer triggered](https://learn.microsoft.com/azure/azure-functions/functions-bindings-timer) function.

Whilst we're going to collect the secrets and settings from our environment variable settings in the function app, we won't have access to those locally (well, we could if we utilised an [Azure App Configuration](https://learn.microsoft.com/azure/azure-app-configuration/overview) instance, but we're not going to do that for this project), so we'll need to create a local settings file.

Go and Azure Function development isn't great locally. I'm still working out how to run my function app locally and connect with the debugger in a reliable way using IntelliJ. The problem is that the Azure extension focuses on Java dev, and one doesn't exist for GoLand. It might be better in Visual Studio Code, but I've not tried that yet. So for now I set up 2 files locally. I'll cover that shortly, but when you see it, you'll now know why.

I'm not going to dive into all the detail for this, if you want more info then have a look at the [post I wrote previously]({{< ref "/posts/azure-func-golang-timer" >}} "Azure Functions: GoLang Timer Trigger").

Once it's been created we'll modify the `host.json` file, to configure our custom handler. We're going to compile our application to a binary called `go-func-sql-app`, so we need to update the file to call this application.

```json
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "excludedTypes": "Request"
      }
    }
  },
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[4.*, 5.0.0)"
  },
  "customHandler": {
    "description": {
      "defaultExecutablePath": "go-func-sql-app",
      "workingDirectory": "",
      "arguments": []
    },
    "enableForwardingHttpRequest": true
  }
}
```

We also enable the `enableForwardingHttpRequest` setting which forwards on the HTTP request.

### Creating the function app

We're going to create a new timer triggered function called `get-news-items`. We do this by using the new `func new` command, and then selecting the timer trigger template. This creates a new directory called `get-news-items` and a `function.json` file.

The first thing we're going to do is modify the `function,json` file to look like the following.

```json
{
  "bindings": [
    {
      "name": "myTimer",
      "type": "timerTrigger",
      "direction": "in",
      "schedule": "0 */20 * * * *",
      "runOnStartup": false
    }
  ]
}
```

This changes the function to run every 20 minutes, which we want to do to make sure we don't use up all of our quota.
