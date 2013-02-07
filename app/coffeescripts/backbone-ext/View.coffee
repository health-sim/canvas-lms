define [
  'use!vendor/backbone'
  'underscore'
  'str/htmlEscape'
], (Backbone, _, htmlEscape) ->

  ##
  # Extends Backbone.View on top of itself to be 100X more useful
  class Backbone.View extends Backbone.View

    ##
    # Define default options, options passed in to the view will overwrite these
    #
    # @api public

    defaults: {}

    ##
    # Configures elements to cache after render. Keys are css selector strings,
    # values are the name of the property to store on the instance.
    #
    # Example:
    #
    #   class FooView extends Backbone.View
    #     els:
    #       '.toolbar': '$toolbar'
    #       '#main': '$main'
    #
    # @api public

    els: null

    ##
    # Defines a key on the options object to be added as an instance property
    # like `model`, `collection`, `el`, etc.
    #
    # Example:
    #   class SomeView extends Backbone.View
    #     @optionProperty 'foo'
    #   view = new SomeView foo: 'bar'
    #   view.foo #=> 'bar'
    #
    #  @param {String} property
    #  @api public

    @optionProperty: (property) ->
      @__optionProperties__ = (@__optionProperties__ or []).concat [property]

    ##
    # Avoids subclasses that simply add a new template

    @optionProperty 'template'

    ##
    # Defines a child view that is automatically rendered with the parent view.
    # When creating an instance of the parent view the child view is passed in
    # as an `optionProperty` on the key `name` and its element will be set to
    # the first match of `selector` in the parent view's template.
    #
    # Example:
    #   class SearchView
    #     @child 'inputFilterView', '.filter'
    #     @child 'collectionView', '.results'
    #
    #   view = new SearchView
    #     inputFilterView: new InputFilterView
    #     collectionView: new CollectionView
    #   view.inputFilterView? #=> true
    #   view.collectionView? #=> true
    #
    # @param {String} name
    # @param {String} selector
    # @api public

    @child: (name, selector) ->
      @optionProperty name
      @__childViews__ ?= []
      @__childViews__ = @__childViews__.concat [{name, selector}]

    ##
    # Initializes the view.
    #
    # - Stores the view in the element data as 'view'
    # - Sets @model.view and @collection.view to itself
    #
    # @param {Object} options
    # @api public

    initialize: (options) ->
      @options = _.extend {}, @defaults, @options, options
      @setOptionProperties()
      @$el.data 'view', this
      @model.view = this if @model
      @collection.view = this if @collection
      this

    ##
    # Sets the option properties
    #
    # @api private

    setOptionProperties: ->
      for property in @constructor.__optionProperties__
        @[property] = @options[property] if @options[property]?

    ##
    # Renders the view, calls render hooks
    #
    # @api public

    render: =>
      @renderEl()
      @_afterRender()
      this

    ##
    # Renders the HTML for the element
    #
    # @api public

    renderEl: ->
      @$el.html @template(@toJSON()) if @template

    ##
    # Caches elements from `els` config
    #
    # @api private

    cacheEls: ->
      @[name] = @$(selector) for selector, name of @els if @els

    ##
    # Internal afterRender
    #
    # @api private

    _afterRender: ->
      @cacheEls()
      @createBindings()
      @afterRender()
      # TODO: remove this when `options.views` is removed
      @renderViews() if @options.views
      # renderChildViews must come last! so we don't cache all the
      # child views elements, bind them to model data, etc.
      @renderChildViews()

    ##
    # Define in subclasses to add behavior to your view, ie. creating
    # datepickers, dialogs, etc.
    #
    # Example:
    #
    #   class SomeView extends Backbone.View
    #     els: '.dialog': '$dialog'
    #     afterRender: ->
    #       @$dialog.dialog()
    #
    # @api private

    afterRender: ->

    ##
    # Defines the locals for the template with intelligent defaults.
    #
    # Order of defaults, highest priority first:
    #
    # 1. `@model.present()`
    # 2. `@model.toJSON()`
    # 3. `@colleciton.present()`
    # 4. `@colleciton.toJSON()`
    # 5. `@options`
    #
    # Using `present` is encouraged so that when a model or collection is saved
    # to the app it doesn't send along non-persistent attributes.
    #
    # Also adds the view's `cid`.
    #
    # @api public

    toJSON: ->
      model = @model or @collection
      json = if model
        if model.present
          model.present()
        else
          model.toJSON()
      else
        @options
      json.cid = @cid
      json

    ##
    # Finds, renders, and assigns all child views defined with `View.child`.
    #
    # @api private

    renderChildViews: ->
      return unless @constructor.__childViews__
      for {name, selector} in @constructor.__childViews__
        target = @$ selector
        @[name].setElement target
        @[name].render()
      null

    ##
    # Binds a `@model` data to the element's html. Whenever the data changes
    # the view is updated automatically. The value will be html-escaped by
    # default, but the view can define a format method to specify other
    # formatting behavior with `@format`.
    #
    # Example:
    #
    #   <div data-bind="foo">{I will always mirror @model.get('foo') in here}</div>
    #
    # @api private

    createBindings: (index, el) =>
      @$('[data-bind]').each (index, el) =>
        $el = $ el
        attribute = $el.data 'bind'
        @model.on "change:#{attribute}", (model, value) =>
          $el.html @format attribute, value

    ##
    # Formats bound attributes values before inserting into the element when
    # using `data-bind` in the template.
    #
    # @param {String} attribute
    # @param {String} value
    # @api private

    format: (attribute, value) ->
      htmlEscape value

    ##
    # Use in cases where normal links occur inside elements with events.
    #
    # Example:
    #
    #   class RecentItemsView
    #     events:
    #       'click .header': 'expand'
    #       'click .something a': 'stopPropagation'
    #
    # @param {$Event} event
    # @api public

    stopPropagation: (event) ->
      event.stopPropagation()

    ##
    # Mixes in objects to a view's definition, being mindful of certain
    # properties (like events) that need to be merged also.
    #
    # @param {Object} mixins...
    # @api public

    @mixin: (mixins...) ->
      for mixin in mixins
        for key, prop of mixin
          # don't blow away old events, merge them
          if key is 'events'
            _.extend @::[key], prop
          else
            @::[key] = prop

    ##
    # DEPRECATED - don't use views option, use `child` constructor method
    renderViews: ->
      console?.warn? 'the `views` option is deprecated in favor of @child`'
      _.each @options.views, @renderView

    ##
    # DEPRECATED
    renderView: (view, selector) =>
      target = @$("##{selector}")
      target = @$(".#{selector}") unless target.length
      view.setElement target
      view.render()
      @[selector] ?= view

  Backbone.View

