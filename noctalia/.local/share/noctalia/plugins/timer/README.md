# Timer sound override

This is a local override of the MIT-licensed `noctalia/timer` 1.2.1 plugin from
<https://github.com/noctalia-dev/official-plugins/tree/main/timer>.

It keeps the upstream bar widget, panel, and countdown service. The local change
loads `alarm-clock-elapsed.oga` through `noctalia.sound` and plays it once when
the countdown reaches zero. The notification and red completion state remain
unchanged.
