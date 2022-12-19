# elm-sciter
This is a quick and dirty attempt to use [Elm](https://elm-lang.org/) with [Sciter](https://sciter.com/). It seem like quite a good match at a first glance to create lightweight native applications for different platforms that are also maintainable.

Elm's virtual dom does not work out of the box but Sciter has a [native implementation](https://sciter.com/tutorials/reactor-rendering/) that can be used with ports. Also XMLHttpRequest needs to be simulated. As an upside, other APIs could also potentially be used with the XMLHttpRequest "hack".

I have not mutch time right now to explorer this further but it seems to be possible to create something useful with a bit of work.

## How to use
Just build the Elm project in the elm folder with `elm make ./src/Main.elm --output elm.js` and then use `index.html` to run with [`scapp`](https://sciter.com/scapp/) (only tested on Windows 11)

