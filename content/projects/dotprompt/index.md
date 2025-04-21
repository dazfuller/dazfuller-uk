+++
title = 'DotPrompt'
date = 2025-04-21T12:33:34+01:00
draft = true
tags = ['open source', 'golang', 'dotnet']
featured_image = 'example-prompt.webp'
+++

Bored of modifying source code files each time a change was needed to a prompt, the idea of DotPrompt landed. A way to hold the prompt information in an editable file which could be modified at runtime, which could also hold other information such as temperature and maximum tokens.

When I was creating it the idea seemed to have surfaced elsewhere as well, with initiatives from Google as part of GenKit, and from Microsoft in the form of Prompty.

So, why did I stick with my own? Well, for a few reasons, but chief amongst them being.

1. It's intended to do one thing simply
2. I wanted it to be extensible
3. I didn't want to be locked in to any particular ecosystem

The first version written is for DotNet and is available on [Github](https://github.com/elastacloud/DotPrompt/) and to use via [Nuget](https://www.nuget.org/packages/DotPrompt), most tooling comes out for JavaScript or Python first with other languages left languishing. But C# is still a major player in large organisations, so why should those devs miss out.

As a spare time project I also implemented a version for Go, which is also available on [Github](https://github.com/dazfuller/dotprompt) and with documentation over on [go.dev](https://pkg.go.dev/github.com/dazfuller/dotprompt). I wanted to have a solution where I could take prompt files written for one, and then use them in the other. The API is also as similar as I could make them, but obviously not identical because of language and style differences.

## :question: What is it?

It's an open-source library which reads files with a `.prompt` extension and makes them available to the application for using in GenAI solution. It supports templating which allows the prompt file to specify parameters and the values are injected at runtime to create the final prompt.

The prompt files themselves are just YAML, so they're easy to create and read. The other solutions have a variation which use YAML for the config, and then delimiters for the textual parts. I'm not a massive fan of this as YAML can handle text just fine, but it's on my roadmap to have the library be able to parse both formats.

So, you could have a template like this.

```text
I want to book a holiday to {{ location }}, what do I need to know as a traveller come from {{ home }}.
```

Providing values at runtime the prompt is evaluated on each call to generate the prompt which is sent off to the LLM. So something like.

```text
I want to book a holiday to Australia, what do I need to know as a traveller come from Greenland.
```

The parameters are available to both the system and user prompt, allowing both to be tweaked at runtime.

## What's a prompt file?

In it's most simplistic form DotPrompt is a library which can read a prompt file, and then takes parameters to return the system and user prompts. The prompt file is core to all of this, so lets have a look at one.

```yaml
name: Example
config:
  outputFormat: text
  temperature: 0.9
  maxTokens: 500
  input:
    parameters:
      topic: string
      style?: string
    default:
      topic: social media
prompts:
  system: |
    You are a helpful research assistant who will provide descriptive responses for a given topic and how it impacts society
  user: |
    Explain the impact of {{ topic }} on how we engage with technology as a society
    {% if style -%}
    Can you answer in the style of a {{ style }}
    {% endif -%}
fewShots:
  - user: What is Bluetooth
    response: Bluetooth is a short-range wireless technology standard that is used for exchanging data between fixed and mobile devices over short distances and building personal area networks.
  - user: How does machine learning differ from traditional programming?
    response: Machine learning allows algorithms to learn from data and improve over time without being explicitly programmed.
  - user: Can you provide an example of AI in everyday life?
    response: AI is used in virtual assistants like Siri and Alexa, which understand and respond to voice commands.
```

At the top of the file we define a name for the prompt (though if we don't specify one then the library uses the file name). The names have to be unique in an application when using the manager, which we'll come to in a bit.

At the head of the file is the `config` section which defines the different options we want to send to the LLM and the parameters we want to use. You can see that the `style` parameter has a question mark after the name, this indicates that it's an option parameter. If the user doesn't specify it then the library doesn't mind and will either use no value, or a default if one is specified. If a parameters isn't optional, and no value is provided, and there's no default, then the library throws an exception at runtime.

Following the config there's the `prompts` section which defines the system and user prompts. This is what I mean about YAML being able to handle text well. The text can be written in any of the following way.

```yaml
text: The ships hung in the sky, in the same way that bricks don't

# Produces
# The ships hung in the sky, in the same way that bricks don't
```

```yaml
text: |
  The ships hung in the sky,
  in the same way that bricks don't

# Produces
# The ships hung in the sky,
# in the same way that bricks don't
```

```yaml
text: >
  The ships hung in the sky,
  in the same way that bricks don't

# Produces
# The ships hung in the sky, in the same way that bricks don't
```

When using the `|` or `>` you can also add a `-` after them which trims additional line breaks, such as `|-`.

At the end of the prompt file we have a `fewShots` section where we can provide some [few-shot prompt](https://www.promptingguide.ai/techniques/fewshot) examples. This effectively allows us to add a chat history to the request which can be help guide the LLM in the output it generates.

## What else can the library do.

Well, as I mentioned before, there's the Manager feature, there's also interfaces which allow the library to be used in different ways.

### Prompt Manager

This is the most likely way in which the library is used. Handling a single prompt file is fine, but when you have multiple it's easier to have a way of just loading up the one you want by name. This is what the prompt manager does.

By default it will look for a `prompts` directory in the current working directory and then look through the directory recursively and load in all the prompt files it finds. If the file has a name property then it uses this, otherwise it uses the file name (without the extension) as the name.

You then use the manager to load a prompt file and use it in the code. Like this using the DotNet library.

```csharp
var promptManager = new PromptManager();
var promptFile = promptManager.GetPromptFile("example");

// The system prompt and user prompt methods take dictionaries containing the values needed for the
// template. If none are needed you can simply pass in null.
var systemPrompt = promptFile.GetSystemPrompt(null);
var userPrompt = promptFile.GetUserPrompt(new Dictionary<string, object>
{
    { "topic", "bluetooth" },
    { "style", "used car salesman" }
});
```

Or, in Go.

```go
promptManager, err := dotprompt.NewManager()
if err != nil {
  panic(err)
}

prompt, err := promptManager.GetPromptFile("example")
if err != nil {
  panic(err)
}

parameters := map[string]interface{}{
  "topic": "bluetooth",
  "style": "used car salesman"
}

systemPrompt, err := prompt.GetSystemPrompt(parameters)
if err != nil {
  panic(err)
}

userPrompt, err := prompt.GetUserPrompt(parameters)
if err != nil {
  panic(err)
}
```

### Different stores

The prompt manager can also take other instances which implement the `IPromptStore` in DotNet, or the `Loader` interface in Go. This allows the manager to work with different sources which the developer can define. So if you want to store the prompt files in something like Sqlite, an S3 bucket, or something else, then you can do.

There's an example of using an Azure Storage Table in the [Github README](https://github.com/elastacloud/DotPrompt/?tab=readme-ov-file#creating-a-custom-prompt-store). As long as it can return a hydrated prompt file instance, then you can use it as a store.

## Testing?

The library was written with testing in mind, so there's no internal default constructors or such craziness (looking at you here Microsoft), and it's interface driven, so you can mock out the bits you need to when running your own tests.

## What next?

So in the roadmap are a few items which I'm hoping to start on soon. It's open-source as well, so if other people want to submit ideas then I'm open to them.

* Add JSON schema support
* Implement support for reading prompt files for GenKit and Prompty
* Create libraries for other languages
* Add other configuration options
