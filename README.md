# Twitch Blame
Experience the torture of backseat programming by getting chatters coding opinions directly in your emacs editor
with a fringe indicator on the relavant line and chat comments in the minibuffer.
![options](https://i.imgur.com/8LqSVuh.png)

## Installation
### Vanilla
Vanilla emacs users can add the `twitch-blame.el` file to any path in their `load-path` variable and require
the package using `(require 'twitch-blame-mode)`. Then set the appropriate

### Doom Emacs
Doom users can install the package directly from the repository using the `package!` macro along with a `:recipe`
```lisp
(package! twitch-blame-mode
  (:host github :repo "skykanin/twitch-blame"))
```

## Configuration
The package requires that you configure three variables:
- `twitch-channel-name` to the name of your twitch channel
- `twitch-nick` to your twitch username
- `twitch-token` to your twitch oauth irc token
