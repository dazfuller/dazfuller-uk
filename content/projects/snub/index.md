+++
title = 'snub'
date = 2025-09-06T13:30:33+01:00
draft = true
tags = ['open source', 'golang', 'cli', 'git']
featured_image = 'cover.webp'
+++
One of the things I frequently get annoyed by - or disgruntled by, it's not really keeping me awake at night - is this. I've started a new project, I initialise the git repository, I'm about to make the first commit, and I remember to create a git ignore file, but there's no cli tool to do it. So I head to something like [gitignore.io](https://gitignore.io) and create one from there, copy it to the right place, and then carry on. That break from the command line is annoying.

Recently I had to do this again and thought sod it, I'll just try and find something. I found some instructions on creating aliases for gitignore.io, but I happened to be somewhere with patchy internet and thought this wouldn't be great. I found something else which sort of did what I wanted, but it was Mac only, and I wanted this on my Macbook and my Linux laptop. So, bugger it, I'll just write it myself.

So, I started to write an app called `fig`, then I did an internet search and found that there was already a project called this and, despite being deprecated, it was pretty popular and had a sizeable following, so I figured I'd rename it. I looked up alternative words for "ignore" and "snub" was listed, so I picked that.

## Features

I wanted two primary features for a v1 release:

1. List the available templates and search for the one I want
2. Create a new gitignore file from one or more templates or append to an existing one

Other features I wanted in there as well were:

1. For the app to be usable offline
2. Generate to stdout instead of a file

I didn't want to faff with flags, so I created this as a [cobra](https://github.com/spf13/cobra-cli) based cli using the generator. Added my two commands and set to it. Within a couple of hours I had a working version which uses gitignore.io under the hood. It keeps a copy of the templates locally so it can be used offline, though it periodically updates itself as well (unless you tell it not to).

## The application

![snub](snub-create.gif "Creating an ignore file using snub")

And it works exactly as I wanted it to. I created a [goreleaser](https://goreleaser.com) config, so I could create binaries for Linux, Mac, and Windows, for x86-64 and ARM64 architectures. At some point I'll look at creating packages to install across platforms in an easier way, like Homebrew.

I've now used it for a few new repos, and I've got some ideas for some new features which I'll add in soon.

## Where to find it

The code is on [Codeberg](https://codeberg.org/dazfuller/snub) along with some instructions on how to use it, though the app also has help text built in.
