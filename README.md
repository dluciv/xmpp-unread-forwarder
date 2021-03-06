![Soviet Jabber textbook](jabber-textbook.jpg)

Small script that connects to several XMPP servers, asks all
other clients to forward unread messages to it and forwards
them to given resource then.

Example use case
================

![Gripping and abusing chat](t-rex-chatting.gif)

I participate in gripping (and probably abusing) Jabber chat using
office computer. Approximately as the picture shows. Then something
makes me to leave immediately. My client software continues receiving
messages. When I come home, my home client goes online and its priority
becomes highest, so it receives messages by default from now.

But I should ask my office Jabber client to forward all unread messages
to my home one to be up to date and to continue chatting.

The straightforward way is to use UI. When I have N accounts and M clients
in different places, I should execute Nx(M-1)
[ad hoc commands](http://xmpp.org/extensions/xep-0050.html)
to receive messages. It is very simple way to drive me crazy, really.

Or I can just launch *one* script that works for few seconds and exits then.
This way is considerably better, isn't it?

Requirements
============

Client Software
---------------

Unfortunately there is no predefined [ad hoc command](http://xmpp.org/extensions/xep-0050.html)
for message forwarding.

This script supports forwarding messages to any messenger from:

* [Psi+](http://psi-plus.com/)
* [Psi](http://psi-im.org/)
* [Miranda NG](http://www.miranda-ng.org/ru/)
* [Tkabber](http://tkabber.jabber.ru/)
* [Gajim](http://gajim.org/) — good client and the *only* one found with forward messages ad-hoc node named `forward-messages` instead of conventional `http://jabber.org/protocol/rc#forward` %)
* [Azoth](https://leechcraft.org/)
* Probably a lot of other clients not tested by me

Some clients did not expose any ad hoc commands about unread messages forwarding (or at least I failed to persuade them):

* [Pidgin](https://pidgin.im/) — suddenly... it has rich feature set but so it is
* [jabber.el](http://www.emacswiki.org/emacs/JabberEl)
* [Conversations](https://conversations.im/) — no surprise here, it's mobile one

Software to run this Script
---------------------------

* [Node.js 0.10.17+](https://nodejs.org/) or [JXcore 0.3.0.7+](http://jxcore.com/) with working NPM which will satisfy all dependencies automatically

Instructions
============

1. Get script itself and satisfy all above dependencies: `npm install git+https://github.com/dluciv/xmpp-unread-forwarder.git`
2. Create [JSON](http://json.org/) config file based on `example.cfg`. Store it in some **secure** place. Passwords are **unencrypted** in it. `"preferred-sasl": "PLAIN"` setting is required for some servers.
3. Run `WHERE_YOU_ARE/node_modules/.bin/xmppfwd YOUR_CONFIG_FILE` or `WHERE_YOU_ARE\node_modules\.bin\xmppfwd.cmd  YOUR_CONFIG_FILE`. It will do the work.
4. Automate it somehow. Execute it every time your local client gets online.
5. Enjoy.

Technical comments
==================

There is actually a lot of XMPP client libraries and, at the same time, a lack of good simple and
lightweight cross-platform ones.

Probably the main reason for it is that XMPP actually goes to kick the bucket. It lacks mobile features — its design
just does not correstpond to mobile use cases. It defines [message carbons](http://xmpp.org/extensions/xep-0280.html)
and [server history features](http://xmpp.org/extensions/xep-0313.html) to keep history up to date everywhere, but it
is nearly impossible to find out running clients and servers doing this well. Despite of all this XMPP still does
look very good for me when compared to its friends. Other ones are either propietary and vendor-based or even work worse than XMPP itself, and most of them do actually have the both properties =).

Right now I see only http://matrix.org/ being designed good enough to become real competitor to XMPP.

For such a small script, Node XMPP Client has shown itself better than other libraries for scripting languages.
But even itself looks imperfect. Still and all, my knowledge of both this library and Node.js itself is even worse. My
XMPP knowledge could also be much better. So technical suggestions are welcome =).
