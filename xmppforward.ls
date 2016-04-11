fs = require \fs
nxc = require \node-xmpp-client
events = require \events
pr = require \prelude-ls

# Forward unread Messages is imlemented in different ways for different clients
commandnodes =
  'http://jabber.org/protocol/rc#forward' # Psi+, Psi, Tkabber, Miranda, LeechCraft Azoth
  'forward-messages' # Gajim (lone and proud %) )

# Workaround for buggy JID parser https://github.com/node-xmpp/node-xmpp-client/issues/141
str2jid = (str)->
  jr = str.split '/'
  if jr.length == 1
    new nxc.JID str
  else
    j = new nxc.JID jr[0]
    j.resource = jr[1]
    j

# (nearly compact)-flip-map
cfmap = (l, fn)->
  pr.filter (!= void), (pr.map fn, l)

class ResourceConversation

  (@client, @targetjid, @finished)~>
    @received_messages = 0
    @inbound = new events.EventEmitter()
    @inbound.once 'evt', @handle_presence

  handle_presence: (msg)!~>
    @interlocutor = msg.attrs.from
    @convid = "#{Math.random()}-#{@interlocutor}"
    @inbound.once 'evt', @handle_commands
    @client.send """<iq type="get" to="#{@interlocutor}" id="#{@convid}">
        <query xmlns="http://jabber.org/protocol/disco\#items" node="http://jabber.org/protocol/commands"/>
      </iq>"""

  unknown_stanza: (stz)!~>
    console.error """UNKNOWN STANZA:
      [[[ #{stz.toString!} ]]]"""

  forward: (msg)!~>
    msg.attrs.from = msg.attrs.to # from this script
    msg.attrs.to = @targetjid
    @client.send msg
    @received_messages += 1

  handle_commands: (iq)!~>
    # look through available ad-hoc commands and find known forwarding ones
    if iq.is 'iq' and iq.type == 'error'
      cfmap iq.children, (iqc)~>
        if iqc.is 'error'
          cfmap iqc.children, (fni)~>
            if fni.is 'feature-not-implemented'
              @finished 0, "#{@interlocutor} does not support ad-hocs"

    else if iq.is 'iq' and iq.type == 'result'
      cmd = pr.head <| pr.intersection commandnodes, (pr.flatten cfmap iq.children, (query)->
        if query.name != 'query'
          void
        else cfmap query.children, (item)->
            if item.name != 'item'
              void
            else
              item.attrs.node)

      if void != cmd
        console.log "#{@interlocutor} exposes \"#{cmd}\""
        @inbound.on 'evt', @handle_message # many messages, so not `once`
        @client.send """<iq type="set" to="#{@interlocutor}">
            <command xmlns="http://jabber.org/protocol/commands" node="#{cmd}"/>
          </iq>"""
      else
        @finished 0, "#{@interlocutor} exposed no known commands"

    else
      @unknown_stanza iq


  handle_message: (msg)!~>
    if msg.is 'message'
      @forward msg
    else if msg.is 'iq'
      for command in msg.children
        if command.name == 'command'
          if msg.attrs.type == 'result' and command.attrs.status == 'completed'
            @finished @received_messages, "#{@interlocutor} forwarded messages"
          else if msg.attrs.type == 'error'
            @finished @received_messages, "#{@interlocutor} sent an error when forwarding messages"
          else
            @unknown_stanza msg
    else
      @unknown_stanza msg

# ----

process_account = (connjidstr, targetresource, mypassword)!->
  connjid = str2jid connjidstr
  connjid.resource = 'unread-forwarder'
  targetjid = new nxc.JID connjid.local, connjid.domain, targetresource
  client = new nxc.Client do
    autostart: false
    jid: connjid.toString!
    password: mypassword
  
  do
    conn_data <-! client.addListener 'online'
    console.log "Connected as #{conn_data.jid.local}@#{conn_data.jid.domain}/#{conn_data.jid.resource}."

    conversations = {}

    var
      nondegenerate_resources_found
      forwarded

    nondegenerate_resources_found := false
    forwarded := 0

    check_and_finish_account = !->
      if pr.empty pr.keys conversations
        # When all resources are processed, wait 3 s., disconect and end up with this account
        (pr.flip setTimeout) 3000, !->
          account_processed "#{targetjid}, forwarded #{forwarded} messages"
          client.connection.end!

    # Get ready to handle incoming stanzas
    do
      stanza <-! client.on 'stanza'

      if conversations[stanza.attrs.from] # when there is a conversation -- leave all to it
        conversations[stanza.attrs.from].inbound.emit 'evt', stanza

      else if stanza.is 'presence'
        if stanza.attrs.type == "error"
          # console.log "!- err presence from #{stanza.attrs.from}"
          {}
        else
          prjid = str2jid stanza.attrs.from
          # Check if it is one of our account's resources online
          if prjid.local == conn_data.jid.local and prjid.domain == conn_data.jid.domain
            # If it is not this bot itself and not target resource, initiate forwarding from it after 1,5 s.
            if prjid.resource != conn_data.jid.resource and prjid.resource != targetresource
              console.log """<-! presence #{prjid}, resource #{prjid.resource}"""

              nondegenerate_resources_found := true
              clearTimeout degenerate_timeout

              (pr.flip setTimeout) 1500, !->
                conversations[stanza.attrs.from] = new ResourceConversation client, targetjid, (cnt, msg)!->
                  delete conversations[stanza.attrs.from]
                  forwarded := forwarded + cnt
                  console.log msg
                  check_and_finish_account!
                conversations[stanza.attrs.from].inbound.emit 'evt', stanza
            else
              # console.log """|- presence #{prjid}, resource #{prjid.resource} -- not asking to forward from"""
              {}

      else
        # console.error """UNKNOWN stanza
        #  [[[ #{stanza} ]]]"""
        {}
  
    # Send presence so server will send contacts' and our resources' presences back to us;
    # low priority and invisible
    client.send """
            <presence>
            <priority>0</priority>
            <show>invisible</show>
            <c xmlns="http://jabber.org/protocol/caps" />
            </presence>
            """  

    # For situation when only this script and/or target resource is connected to account -- wait for 15 s. and finish it.
    degenerate_timeout = (pr.flip setTimeout) 15000, !->
      if not nondegenerate_resources_found
        console.log "No non-degenerate resources under #{connjid}..."
        check_and_finish_account!

  do
    cerr <-! client.on 'error'
    account_processed "#{targetjid}, client error: #{cerr}"

  console.log "Connecting to #{connjid}..."
  client.connect()    
  
  do
    err <-! client.connection.socket.on 'error'
    console.error err
    account_processed "#{targetjid}, connection error!"

# ----------------------

var remaining_accounts
remaining_accounts := 0

account_processed = (jid)!->
  remaining_accounts = remaining_accounts - 1
  console.log "Done with #{jid}."
  if remaining_accounts == 0
    console.log "No more accounts to process."
    process.exit 0
    

config_filename = pr.last process.argv

do
  err, cfgfc <-! fs.readFile config_filename, 'utf8'
  cfg = JSON.parse cfgfc
  for acc in cfg
    remaining_accounts := remaining_accounts + 1
    process_account acc.jid, acc.resource, acc.password
