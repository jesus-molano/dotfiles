import catppuccin
config.load_autoconfig()
catppuccin.setup(c, 'mocha', True)

c.url.searchengines = {
    'DEFAULT':  'https://google.com/search?hl=en&q={}',
    'd':       'https://duckduckgo.com/?ia=web&q={}',
    'gh':      'https://github.com/search?o=desc&q={}&s=stars',
    'gist':    'https://gist.github.com/search?q={}',
    'gi':      'https://www.google.com/search?tbm=isch&q={}&tbs=imgo:1',
    'm':       'https://www.google.com/maps/search/{}',
    'w':       'https://en.wikipedia.org/wiki/{}',
    'nxs':     'https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query={}',
    'aur':     'https://aur.archlinux.org/packages/?O=0&K={}',
    'yt':      'https://www.youtube.com/results?search_query={}'
}
config.bind('xs', 'config-cycle statusbar.show always never')
config.bind('xt', 'config-cycle tabs.show always never')
config.bind('xx', 'config-cycle tabs.show always never;; config-cycle statusbar.show always never')
config.bind('xm', 'hint links spawn mpv --ytdl-format=bestvideo+bestaudio/best {hint-url}')
config.bind('xM', 'spawn mpv --ytdl-format=bestvideo+bestaudio/best "{url}"')

