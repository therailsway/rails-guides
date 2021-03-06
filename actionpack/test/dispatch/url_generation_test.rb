# frozen_string_literal: true

require "abstract_unit"

module TestUrlGeneration
  class WithMountPoint < ActionDispatch::IntegrationTest
    Routes = ActionDispatch::Routing::RouteSet.new
    include Routes.url_helpers

    class ::MyRouteGeneratingController < ActionController::Base
      include Routes.url_helpers
      def index
        render plain: foo_path
      end

      def add_trailing_slash
        render plain: url_for(trailing_slash: true, params: request.query_parameters, format: params[:format])
      end

      def trailing_slash_default
        if params[:url]
          render plain: trailing_slash_default_url(format: params[:url_format])
        else
          render plain: trailing_slash_default_path(format: params[:url_format])
        end
      end
    end

    Routes.draw do
      get "/foo", to: "my_route_generating#index", as: :foo
      get "(/optional/:optional_id)/baz", to: "my_route_generating#index", as: :baz
      get "/add_trailing_slash", to: "my_route_generating#add_trailing_slash", as: :add_trailing_slash
      get "/trailing_slash_default", to: "my_route_generating#trailing_slash_default", as: :trailing_slash_default, trailing_slash: true

      resources :bars

      mount MyRouteGeneratingController.action(:index), at: "/bar"
    end

    APP = build_app Routes

    def _routes
      Routes
    end

    def app
      APP
    end

    test "generating URLS normally" do
      assert_equal "/foo", foo_path
    end

    test "accepting a :script_name option" do
      assert_equal "/bar/foo", foo_path(script_name: "/bar")
    end

    test "the request's SCRIPT_NAME takes precedence over the route" do
      get "/foo", headers: { "SCRIPT_NAME" => "/new", "action_dispatch.routes" => Routes }
      assert_equal "/new/foo", response.body
    end

    test "the request's SCRIPT_NAME wraps the mounted app's" do
      get "/new/bar/foo", headers: { "SCRIPT_NAME" => "/new", "PATH_INFO" => "/bar/foo", "action_dispatch.routes" => Routes }
      assert_equal "/new/bar/foo", response.body
    end

    test "handling http protocol with https set" do
      https!
      assert_equal "http://www.example.com/foo", foo_url(protocol: "http")
    end

    test "respects secure_protocol configuration when protocol not present" do
      old_secure_protocol = ActionDispatch::Http::URL.secure_protocol

      begin
        ActionDispatch::Http::URL.secure_protocol = true
        assert_equal "https://www.example.com/foo", foo_url(protocol: nil)
      ensure
        ActionDispatch::Http::URL.secure_protocol = old_secure_protocol
      end
    end

    test "extracting protocol from host when protocol not present" do
      assert_equal "httpz://www.example.com/foo", foo_url(host: "httpz://www.example.com", protocol: nil)
    end

    test "formatting host when protocol is present" do
      assert_equal "http://www.example.com/foo", foo_url(host: "httpz://www.example.com", protocol: "http://")
    end

    test "default ports are removed from the host" do
      assert_equal "http://www.example.com/foo", foo_url(host: "www.example.com:80", protocol: "http://")
      assert_equal "https://www.example.com/foo", foo_url(host: "www.example.com:443", protocol: "https://")
    end

    test "port is extracted from the host" do
      assert_equal "http://www.example.com:8080/foo", foo_url(host: "www.example.com:8080", protocol: "http://")
      assert_equal "//www.example.com:8080/foo", foo_url(host: "www.example.com:8080", protocol: "//")
      assert_equal "//www.example.com:80/foo", foo_url(host: "www.example.com:80", protocol: "//")
    end

    test "port option is used" do
      assert_equal "http://www.example.com:8080/foo", foo_url(host: "www.example.com", protocol: "http://", port: 8080)
      assert_equal "//www.example.com:8080/foo", foo_url(host: "www.example.com", protocol: "//", port: 8080)
      assert_equal "//www.example.com:80/foo", foo_url(host: "www.example.com", protocol: "//", port: 80)
    end

    test "port option overrides the host" do
      assert_equal "http://www.example.com:8080/foo", foo_url(host: "www.example.com:8443", protocol: "http://", port: 8080)
      assert_equal "//www.example.com:8080/foo", foo_url(host: "www.example.com:8443", protocol: "//", port: 8080)
      assert_equal "//www.example.com:80/foo", foo_url(host: "www.example.com:443", protocol: "//", port: 80)
    end

    test "port option disables the host when set to nil" do
      assert_equal "http://www.example.com/foo", foo_url(host: "www.example.com:8443", protocol: "http://", port: nil)
      assert_equal "//www.example.com/foo", foo_url(host: "www.example.com:8443", protocol: "//", port: nil)
    end

    test "port option disables the host when set to false" do
      assert_equal "http://www.example.com/foo", foo_url(host: "www.example.com:8443", protocol: "http://", port: false)
      assert_equal "//www.example.com/foo", foo_url(host: "www.example.com:8443", protocol: "//", port: false)
    end

    test "keep subdomain when key is true" do
      assert_equal "http://www.example.com/foo", foo_url(subdomain: true)
    end

    test "keep subdomain when key is missing" do
      assert_equal "http://www.example.com/foo", foo_url
    end

    test "omit subdomain when key is nil" do
      assert_equal "http://example.com/foo", foo_url(subdomain: nil)
    end

    test "omit subdomain when key is false" do
      assert_equal "http://example.com/foo", foo_url(subdomain: false)
    end

    test "omit subdomain when key is blank" do
      assert_equal "http://example.com/foo", foo_url(subdomain: "")
    end

    test "keep optional path parameter when given" do
      assert_equal "http://www.example.com/optional/123/baz", baz_url(optional_id: 123)
    end

    test "keep optional path parameter when true" do
      assert_equal "http://www.example.com/optional/true/baz", baz_url(optional_id: true)
    end

    test "omit optional path parameter when false" do
      assert_equal "http://www.example.com/optional/false/baz", baz_url(optional_id: false)
    end

    test "omit optional path parameter when blank" do
      assert_equal "http://www.example.com/baz", baz_url(optional_id: "")
    end

    test "keep positional path parameter when true" do
      assert_equal "http://www.example.com/optional/true/baz", baz_url(true)
    end

    test "omit positional path parameter when false" do
      assert_equal "http://www.example.com/optional/false/baz", baz_url(false)
    end

    test "omit positional path parameter when blank" do
      assert_equal "http://www.example.com/baz", baz_url("")
    end

    test "generating the current URL with a trailing slashes" do
      get "/add_trailing_slash"
      assert_equal "http://www.example.com/add_trailing_slash/", response.body
    end

    test "generating the current URL with a trailing slashes and query string" do
      get "/add_trailing_slash?a=b"
      assert_equal "http://www.example.com/add_trailing_slash/?a=b", response.body
    end

    test "generating the current URL with a trailing slashes and format indicator" do
      get "/add_trailing_slash.json"
      assert_equal "http://www.example.com/add_trailing_slash.json", response.body
    end

    test "generating the path with `trailing_slashes: true` default options" do
      get "/trailing_slash_default"
      assert_equal "/trailing_slash_default/", response.body

      get "/trailing_slash_default?url=1"
      assert_equal "http://www.example.com/trailing_slash_default/", response.body
    end

    test "generating the path with `trailing_slashes: true` default options and format" do
      get "/trailing_slash_default?url_format=json"
      assert_equal "/trailing_slash_default.json", response.body

      get "/trailing_slash_default?url=1&url_format=json"
      assert_equal "http://www.example.com/trailing_slash_default.json", response.body
    end

    test "generating URLs with trailing slashes" do
      assert_equal "/bars/", bars_path(
        trailing_slash: true,
      )
    end

    test "generating URLs with trailing slashes and dot including param" do
      assert_equal "/bars/hax0r.json/", bar_path(
        "hax0r.json",
        trailing_slash: true,
      )
    end

    test "generating URLs with trailing slashes and query string" do
      assert_equal "/bars/?a=b", bars_path(
        trailing_slash: true,
        a: "b"
      )
    end

    test "generating URLs with trailing slashes and format" do
      assert_equal "/bars.json", bars_path(
        trailing_slash: true,
        format: "json"
      )
    end

    test "generating URLS with querystring and trailing slashes" do
      assert_equal "/bars.json?a=b", bars_path(
        trailing_slash: true,
        a: "b",
        format: "json"
      )
    end

    test "generating URLS with empty querystring" do
      assert_equal "/bars.json", bars_path(
        a: {},
        format: "json"
      )
    end
  end
end
