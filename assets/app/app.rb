# frozen_string_literal: true

require 'index'
require 'game_manager'
require 'user_manager'
require 'lib/connection'
require 'lib/storage'
require 'view/about'
require 'view/create_game'
require 'view/home'
require 'view/flash'
require 'view/game'
require 'view/map_page'
require 'view/navigation'
require 'view/tiles_page'
require 'view/user'
require 'view/forgot'
require 'view/reset'

class App < Snabberb::Component
  include GameManager
  include UserManager
  needs :disable_user_errors, default: false
  needs :pin, default: nil

  def render
    props = {
      props: { id: 'app' },
      style: {
        padding: '0.5rem',
        margin: :auto,
      },
    }

    h(:div, props, [
      h(View::Navigation),
      h(View::Flash),
      render_content,
    ])
  end

  def render_content
    store(:connection, Lib::Connection.new(root), skip: true) unless @connection

    refresh_user
    js_handlers

    page =
      case @app_route
      when /new_game/
        h(View::CreateGame)
      when /game|hotseat|tutorial/
        render_game
      when /signup/
        h(View::User, user: @user, type: :signup)
      when /login/
        h(View::User, user: @user, type: :login)
      when /profile/
        h(View::User, user: @user, type: :profile)
      when /forgot/
        h(View::Forgot, user: @user)
      when /reset/
        h(View::Reset, user: @user)
      when /about/
        h(View::About)
      when /tiles/
        h(View::TilesPage, route: @app_route)
      when /map/
        h(View::MapPage, route: @app_route)
      else
        h(View::Home, user: @user)
      end

    props = {
      style: {
        padding: '0 1rem',
        margin: '1rem 0',
      },
    }

    h(:div, props, [page])
  end

  def render_game
    match = @app_route.match(%r{(hotseat|game)\/((hs.*_)?\d+)})

    if !@game_data # this is a hotseat game
      if @app_route.include?('tutorial')
        enter_tutorial
      else
        enter_game(id: match[2], mode: match[1] == 'game' ? :muti : :hotseat, pin: @pin)
      end
    elsif !@game_data['loaded'] && !@game_data['loading']
      enter_game(id: match[2], mode: match[1] == 'game' ? :muti : :hotseat, pin: @pin)
      enter_game(@game_data)
    end

    return h(:div, 'Loading game...') unless @game_data&.dig('loaded')

    h(View::Game, connection: @connection, user: @user, disable_user_errors: @disable_user_errors)
  end

  def js_handlers
    %x{
      var self = this

      if (!window.onpopstate) {
        window.onpopstate = function(event) { self.$on_hash_change(event.state) }
        self.$store_app_route()
      }

      var location = window.location

      if (location.pathname + location.hash + location.search != #{@app_route}) {
        window.history.pushState(#{@game_data.to_n}, #{@app_route}, #{@app_route})
      }
    }
  end

  def on_hash_change(state)
    game_data = Hash.new(state)
    store(:game_data, game_data, skip: true) if game_data.any?
    store_app_route(skip: false)
  end

  def store_app_route(skip: true)
    window_route = `window.location.pathname + window.location.hash + window.location.search`
    store(:app_route, window_route, skip: skip) unless window_route == ''
  end
end
