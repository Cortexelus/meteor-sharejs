
class ShareJSConnector

  getOptions = ->
    origin: '//' + window.location.host + '/channel'
    authentication: Meteor.userId?() or null # accounts-base may not be in the app

  constructor: (parentView) ->
    # Create a ReactiveVar that tracks the docId that was passed in
    docIdVar = new Blaze.ReactiveVar

    parentView.onViewReady ->
      this.autorun ->
        data = Blaze.getData()
        docIdVar.set(data.docid)

    parentView.onViewDestroyed =>
      this.destroy()

    @isCreated = false
    @docIdVar = docIdVar

  create: ->
    console.log "super create"
    throw new Error("Already created") if @isCreated
    connector = this
    @isCreated = true

    @view = @createView()
    @view.onViewReady ->
      connector.rendered( this.firstNode() )

      this.autorun ->
        # By grabbing docId here, we ensure that we only try to connect when
        # this is rendered.
        docId = connector.docIdVar.get()

        # Disconnect any existing connections
        connector.disconnect()
        connector.connect(docId) if docId

    return @view

  # Set up the context when rendered.
  rendered: (element) ->
    this.element = element

  # Connect to a document.
  connect: (docId, element) ->
    @connectingId = docId

    sharejs.open docId, 'text', getOptions(), (error, doc) =>
      if error
        Meteor._debug(error)
        return

      # Don't attach if re-render happens too quickly and we're trying to
      # connect to a different document now.
      unless @connectingId is doc.name
        doc.close() # Close immediately
      else
        @attach(doc)

  # Attach shareJS to the on-screen editor
  attach: (doc) ->
    @doc = doc

  # Disconnect from ShareJS. This should be idempotent.
  disconnect: ->
    # Close connection to the ShareJS doc
    if @doc?
      @doc.close()
      @doc = null

  # Destroy the connector and make sure everything's disconnected.
  destroy: ->
    throw new Error("Already destroyed") if @isDestroyed

    @disconnect()
    @view = null
    @isDestroyed = true

class ShareJSCMConnector extends ShareJSConnector
  constructor: (parentView) ->
    super
    console.log "constructor"
    #return null if @dontConstructItAgain
    params = Blaze.getData(parentView)
    @configCallback = params.onRender || params.callback # back-compat
    @connectCallback = params.onConnect

  createView: ->
    console.log "createView"
    #return null if @dontConstructItAgain
    return Blaze.With(Blaze.getData, -> Template._sharejsCM)

  rendered: (element) ->
    super
    console.log "rendered"
    @cm_original = element

    @cm = CodeMirror(element)
    @configCallback?(@cm)

  connect: -> 
    console.log "connect" 
    @cm.readOnly = true
    super

  attach: (doc) ->
    super
    console.log "attach" 
    doc.attach_cm(@cm)
    @cm.readOnly = false

    #@dontConstructItAgain = true
    @connectCallback?(@cm)

  disconnect: ->
    console.log "disconnect" 
    @cm?.detach_share?()
    super

  destroy: ->
    super
    console.log "destroy"
    # Meteor._debug "destroying cm editor"
    @cm = null
    @cm_original = null

class ShareJSTextConnector extends ShareJSConnector
  createView: ->
    console.log "textarea createView"
    return Blaze.With(Blaze.getData, -> Template._sharejsText)

  rendered: (element) ->
    super
    console.log "textarea rendered"
    @textarea = element

  connect: ->
    console.log "textarea connect"
    @textarea.disabled = true
    super

  attach: (doc) ->
    super
    console.log "textarea attach"
    doc.attach_textarea(@textarea)
    @textarea.disabled = false

  disconnect: -> 
    console.log "textarea disconnect"
    @textarea?.detach_share?()
    super

  destroy: ->
    super
    console.log "textarea destroy"
    # Meteor._debug "destroying textarea editor"
    @textarea = null

UI.registerHelper "sharejsCM", new Template('sharejsCM', ->
  return new ShareJSCMConnector(this).create()
)

UI.registerHelper "sharejsText", new Template('sharejsText', ->
  return new ShareJSTextConnector(this).create()
)
