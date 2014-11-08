CocoView = require 'views/kinds/CocoView'
template = require 'templates/play/level/level-dialogue-view'
DialogueAnimator = require './DialogueAnimator'

module.exports = class LevelDialogueView extends CocoView
  id: 'level-dialogue-view'
  template: template

  subscriptions:
    'sprite:speech-updated': 'onSpriteDialogue'
    'level:sprite-clear-dialogue': 'onSpriteClearDialogue'
    'level:shift-space-pressed': 'onShiftSpacePressed'
    'level:escape-pressed': 'onEscapePressed'
    'sprite:dialogue-sound-completed': 'onDialogueSoundCompleted'

  events:
    'click': 'onClick'

  onClick: (e) ->
    Backbone.Mediator.publish 'tome:focus-editor', {}

  onFrameChanged: (e) ->
    @timeProgress = e.progress
    @update()

  onSpriteDialogue: (e) ->
    return unless e.message
    @$el.addClass 'active speaking'
    @setMessage e.message, e.mood, e.responses

    window.tracker?.trackEvent 'Heard Sprite', {message: e.message, label: e.message}, ['Google Analytics']

  onDialogueSoundCompleted: ->
    @$el.removeClass 'speaking'

  onSpriteClearDialogue: ->
    @$el.removeClass 'active speaking'

  setMessage: (message, mood, responses) ->
    message = marked message
    # Fix old HTML icons like <i class='icon-play'></i> in the Markdown
    message = message.replace /&lt;i class=&#39;(.+?)&#39;&gt;&lt;\/i&gt;/, "<i class='$1'></i>"
    clearInterval(@messageInterval) if @messageInterval
    @bubble = $('.dialogue-bubble', @$el)
    @bubble.removeClass(@lastMood) if @lastMood
    @lastMood = mood
    @bubble.text('')
    group = $('<div class="enter secret"></div>')
    @bubble.append(group)
    if responses
      @lastResponses = responses
      for response in responses
        button = $('<button class="btn btn-small banner"></button>').text(response.text)
        button.addClass response.buttonClass if response.buttonClass
        group.append(button)
        response.button = $('button:last', group)
    else
      s = $.i18n.t('play_level.hud_continue_short', defaultValue: 'Continue')
      sk = $.i18n.t('play_level.skip_tutorial', defaultValue: 'skip: esc')
      if not @escapePressed
        group.append('<span class="hud-hint">' + sk + '</span>')
      group.append($('<button class="btn btn-small banner with-dot">' + s + ' <div class="dot"></div></button>'))
      @lastResponses = null
    @animator = new DialogueAnimator(message, @bubble)
    @messageInterval = setInterval(@addMoreMessage, 1000 / 30)  # 30 FPS

  addMoreMessage: =>
    if @animator.done()
      clearInterval(@messageInterval)
      @messageInterval = null
      $('.enter', @bubble).removeClass('secret').css('opacity', 0.0).delay(500).animate({opacity: 1.0}, 500, @animateEnterButton)
      if @lastResponses
        buttons = $('.enter button')
        for response, i in @lastResponses
          channel = response.channel.replace 'level-set-playing', 'level:set-playing'  # Easier than migrating all those victory buttons.
          f = (r) => => setTimeout((-> Backbone.Mediator.publish(channel, r.event or {})), 10)
          $(buttons[i]).click(f(response))
      else
        $('.enter', @bubble).click(-> Backbone.Mediator.publish('script:end-current-script', {}))
      return
    @animator.tick()

  onShiftSpacePressed: (e) ->
    @shiftSpacePressed = (@shiftSpacePressed || 0) + 1
    # We don't need to handle script:end-current-script--that's done--but if we do have
    # custom buttons, then we need to trigger the one that should fire (the last one).
    # If we decide that always having the last one fire is bad, we should make it smarter.
    return unless @lastResponses?.length
    r = @lastResponses[@lastResponses.length - 1]
    channel = r.channel.replace 'level-set-playing', 'level:set-playing'
    _.delay (-> Backbone.Mediator.publish(channel, r.event or {})), 10

  onEscapePressed: (e) ->
    @escapePressed = true

  animateEnterButton: =>
    return unless @bubble
    button = $('.enter', @bubble)
    dot = $('.dot', button)
    dot.animate({opacity: 0.2}, 300).animate({opacity: 1.9}, 600, @animateEnterButton)

  destroy: ->
    clearInterval(@messageInterval) if @messageInterval
    super()
