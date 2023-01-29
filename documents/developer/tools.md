# Editor

## Getting proper code-completion, documentation and symbol defintions in your editor.

Let your editor make a completion and then run.

```console
./setup_lsp.sh
```

Explanation:
There is a bug in `serve-d` the language server for dlang that does not allow it to specify multiple import paths at startup  
And because the way that sourcetree is structures each primary modules have their own directory.
The script when run will manually tell the completion server `dcd-server` to use the projects import paths.
