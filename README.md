# UILabel+TJTapHandling

This category makes it so you can handle tapped hyperlinks in `UILabel`s. The underlying way I'm doing this uses a strategy [swirling around the internet](https://stackoverflow.com/a/46940367) that I've packaged up nicely. It seems to work pretty well, and the project layers on a pleasant API to use.

To configure link handling, call `addURLHandler:` on your label providing an object that conforms to `TJLabelURLHandler`. `-label:didTapURL:inRange:` will then be called on your handler when a link is tapped within that label's attributed text.