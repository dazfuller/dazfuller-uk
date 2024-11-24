+++
title = 'CI/CD - Shell Out'
date = 2024-11-24T09:51:24Z
tags = ['azure', 'github', 'cli']
+++
After I finished writing my most recent post on using the [Azure SDKs]({{< ref "/posts/azure-sdk-mania" >}} "Azure SDK Mania") I ran into an issue. It wasn't an issue I was expecting (as they so often are not), nor was it an issue I thought I'd have to consider, given that I'm using a static site generator, and hosting using an [Azure Static Web App](https://learn.microsoft.com/azure/static-web-apps/overview).

My build broke!

So, I have a pretty simple setup. I have my [Hugo](https://gohugo.io) site living in Git, I'm using a pretty standard theme, and I just add new posts using the `hugo new content` command, life is easy. Hugo generates the actual site, and then the produced output is uploaded to a static web app instance and boom, you have this site. So how in the world could the build break.

I'd made a couple of other changes before deploying the post as well. I'd moved from using the theme directly as a git sub-module to the newer hugo module system. That needed me to update some of my config because of changes. Nothing major, just little tweaks which I think has made everything a bit better. Once I got it all running locally I pushed my changes and then watched in horror as the build broke. But why? Well, here's the error.

```text
Detecting platforms...
Error: Platform 'golang' version '1.23.3' is unsupported. Supported versions: 1.14.15, 1.15.15, 1.16.7, 1.17, 1.18.10, 1.18.8, 1.18, 1.19.3, 1.19.5, 1.19.7, 1.19, 1.14.15, 1.15.15, 1.16.7, 1.17, 1.18.10, 1.18.8, 1.18, 1.19.3, 1.19.5, 1.19.7, 1.19
```

I am running Go 1.23.1 locally at the moment, so that checks out, but this hasn't been an issue before? Using the newer Hugo module system my site now has a `go.mod` file, a quick check and it's showing that it needs Go 1.23.1. So, I remove that line and run locally again knowing that Go will add it back based on the minimum version required by any dependencies. It does, and it's version 1.22, which is still a few versions after 1.19 (incidentally, the latest version listed as supported is 1.19.7, which was released 7th March 2023, so about 1.5 years ago).

This is all an issue because I'm doing what most devs would do and I followed the docs. So I'm using the Azure Static Web Apps [Github Action](https://github.com/Azure/static-web-apps-deploy) which auto-detects the platform you're using and handles pulling everything together for you and deploying. Which is all nice a super simple, when it works, and it's not working any more. A quick look at the action is not showing a lot of changes, so this might be another thing which has been left to rot by Microsoft.

## Options

So, 2 choices. First, I revert everything back to older versions and submodules and the build keeps working. I don't like this option. I like to keep things up-to-date. So, choice 2, I get rid of the Github Action and do what I probably should have done the entire time, and just script the process. Naturally, I go for choice 2.

## Changing the process

Building the static web app isn't that difficult. In fact it's insanely easy, I just run `hugo` and it's done. But I'm going to experiment using a 'preview' environment in the static web app so I don't mess up the actual site while I'm doing this. Fortunately Hugo lets you override the base URL so all the links work when you deploy somewhere else, simply by using the `--baseURL` argument.

Okay, so I've got my generated content, next I want to deploy. I'm going to use the Static Web App command line tool for this. It doesn't need to know how to build my site, just where the content it's going to deploy is. I already have this locally, but I grab the command to install anyway for later.

Then, to deploy I can run this (grabbing the deployment token from my static web app instance)

```bash
swa deploy -a ./ -d <token> -O ./public --env preview
```

I do that and it deploys fine. I check the deployed preview instance and everything just works.

I quickly put this together in a `justfile` (If you're not using [just](https://github.com/casey/just) you should definitely check it out). Add my token to a `.env` file which can be loaded using just, so I can run this all again quickly later.

```text
set dotenv-load

deploy-test:
    rm -rf ./public
    hugo --baseURL $SWA_PREVIEW_NAME
    swa deploy -a ./ -d $SWA_TOKEN -O ./public --env preview
```

You can see I also put the preview base URL into the `.env` file as well, just to make things easier.

So now I can change my Github Action to follow this process. All it needs to do is

1. Install Go
2. Install Node (I need NPM to install the static web app cli tool)
3. Install Hugo
4. Build the site
5. Deploy the site

```yaml
env:
  GOLANG_VERSION: 1.23.3
  HUGO_VERSION: 0.139.0

jobs:
  build_and_deploy_job:
    if: github.event_name == 'push' || (github.event_name == 'pull_request' && github.event.action != 'closed')
    runs-on: ubuntu-latest
    name: Build and Deploy Job
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: true
          lfs: false
      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '>=${{ env.GOLANG_VERSION }}'
      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v3
        with:
          hugo-version: ${{ env.HUGO_VERSION }}
          extended: true
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 22
      - name: Build And Deploy
        run: |
          npm install -g @azure/static-web-apps-cli
          rm -rf ./public
          hugo
          swa deploy -a ./ -O ./public --env Production -d ${{ secrets.STATIC_WEB_APP_TOKEN }}
```

I'm still using helper actions here to install the tools I need, but the action build and deploy step is now a script, one which looks a lot like the one I have in my `justfile` which I can test. The only difference is that I'm deploying to the Production environment, and I'm using the base URL provided in my Hugo config.

And this just works!

Importantly, this is a process I can test. It's not hidden behind some helper action, I can run these steps and make sure it's doing what I think it should be doing.

## Not a one-off

This isn't the first time I've been here. Previously it's been for things like Azure Function Apps, or Web Apps, Database deployments, and more.

Microsoft Docs are, quite frankly, shit. They will happily show you the quickest way to deploy to get you started, very often using point-and-click features in Visual Studio Code. But these aren't repeatable. They don't fit into CI/CD pipelines. And they rely on Microsoft keeping tools up-to-date. And then, when they go wrong, you're stuck trying to work out what to do.

The best thing you can do is spend that time up-front and work out how to deploy things from the command line so you can script it. Then you can create `Make` files, `Just` files, PowerShell scripts, bash scripts, whatever you want. You can test it locally, you can debug, and you're in control.

How could Microsoft help? Well, they could make sure that the base level information on how to do this is available and easy to locate. Want to show the point-and-click option? Cool, go for it, but after you've shown how to do things a consistent way first.