# Building documentation

## D code documentation

The site for ddoc.tagion.org is generated from the comments in the d source files using adrdox.

Assuming that you have `dub` and a `d` compiler installed to build run.

```
make ddoc
```

The resulting files will be in `build/ddoc`

## Docusaurus docs

The site for docs.tagion.org are a bunch of markdown compiled to html.
The documentation site is based on [docusaurus](https://docusaurus.io/), a documentation generator built by The Facebook.  
You'll need node20 and npm to build it.

**Installation**

```bash
cd docs/
npm install
```

After feeding the black hole you'll be able to build the documentation

**Start a development server**
```
npm run docusaurus start
```


**Build**

This will output the html files docs/dist/

```
npm run build
```
