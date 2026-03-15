# /deploynope-console — DEPRECATED

> **This command has been removed in 2.10.0.** The sidecar console log feature
> (`.deploynope/console.log` + `tail -f`) has been removed because every write to
> the log file required a Bash tool call that cluttered the main chat with permission
> prompts, defeating the purpose of a clean monitoring experience.
>
> DeployNOPE status is now shown exclusively via chat tags using the format
> **`<emoji> DeployNOPE <context> · <Stage>`**. See `/deploynope-deploy` § Framework
> Visibility for details.

If a user runs this command, inform them that the sidecar console has been removed and
that DeployNOPE messages appear directly in the main chat with severity-tagged labels.
