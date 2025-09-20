+++
title = 'Snubbing the Limits'
date = 2025-09-20T15:27:17+01:00
tags = ['open source', 'golang', 'cli', 'git']
featured_image = 'snub-detect.webp'
+++

Whilst I'm working on the first series I've been putting together for this site, I have also been working a small command-line tool to help me with creating gitignore files when I've had a few minutes to spare (which have been few and far between lately).

One of the features I worked on briefly this weekend was to add the ability to auto-detect the right templates based on the projects content. There are quite a lot of templates so I started out with the ones that are most useful to myself first. Hey, I'm writing it, so I get to be a little selfish :wink:

I built in a configuration file which allows me to specify rules for each template, such as the following.

```json
"csharp": {
    "matchAll": false,
    "patterns": [
      "*.csproj",
      "*.cs",
      "**/*.cs"
    ]
}
```

The `matchAll` flag dictates if all the rules should be matched if set to `true`, or if a match is based on any of the rules matching.

The patterns themselves are glob patterns used to match specific files, or to find files which match. In this example we are looking for any `.csproj` or `.cs` files in the current directory, or any `.cs` files in any of the subdirectories.

This file is then embedded into the binary using the [`go:embed`](https://pkg.go.dev/embed) directive and loaded when it needs to detect the templates. This is done using with the `detect` command, or by calling the `create` command without specifying a template.

_Running the `detect` command_

```shell
> snub detect
Detected templates: golang,intellij
Use the following command to create a .gitignore file
snub create -t golang,intellij
```

_Or with the `create` command_

```shell
> snub create
Detected templates: intellij,go
Appended to existing .gitignore file
```

You can still apply the `--stdout` flag to get the output to be printed to the console instead of to a file if you want to see what it would create first.

Right now I'm considering adding an option for users to specify their own templates to extend the existing ones or to override them. Having options is always a good thing.
