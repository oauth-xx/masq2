# encoding: utf-8

ENV["RAILS_ENV"] = "test"

# External libraries
require "minitest/autorun"
require "mocha/minitest"
require "minitest/retry"

Minitest::Retry.use!(
  retry_count:  3,         # The number of times to retry. The default is 3.
  verbose: true,           # Whether to display the message at the time of retry. The default is true.
  io: $stdout,             # Display destination of retry when the message. The default is stdout.
  exceptions_to_retry: [], # List of exceptions that will trigger a retry (when empty, all exceptions will).
  methods_to_retry:    [], # List of methods that will trigger a retry (when empty, all methods will).
  classes_to_retry:    [], # List of classes that will trigger a retry (when empty, all classes will).
  methods_to_skip:     [], # List of methods that will skip a retry (when empty, all methods will retry).
  exceptions_to_skip:  [],  # List of exceptions that will skip a retry (when empty, all exceptions will retry).
)

# We have to set up code coverage early because the gem will be required by the Rails test dummy app.
begin
  # This does not require "simplecov", but
  require "kettle-soup-cover"
  #   this next line has a side effect of running `.simplecov`
  require "simplecov" if defined?(Kettle::Soup::Cover) && Kettle::Soup::Cover::DO_COV
rescue LoadError
  warn("Warning: Could not load simplecov. Code coverage will not be collected.")
end

require "bundler"
Bundler.require :default, :development

# External Libs that Rails, or other deps, are dependent on,
#   yet not all versions of Rails, or other deps, require properly
require "logger"
require "rexml"

Combustion.path = "test/internal"
Combustion.initialize!(:all)

# Internal test config
require "config/debug.rb"

# Rails-dependent external libs
require "rails/test_help"
require "rails-controller-testing"

puts "Rails version is #{Rails.version}"
puts "BUNDLE_GEMFILE: #{ENV["BUNDLE_GEMFILE"]}"

require "masq2"

# Set time zone to UTC for all tests.
Time.zone = "UTC"

Rails::Controller::Testing.install
Rails.backtrace_cleaner.remove_silencers!

module Masq
  class ActionController::TestCase
    include Masq::Engine.routes.url_helpers
    setup do
      @routes = Engine.routes
    end
  end

  module TestHelper
    private

    def valid_account_attributes
      {
        login: "dennisreimann",
        email: "mail@dennisreimann.de",
        password: "123456",
        password_confirmation: "123456",
      }
    end

    def valid_persona_attributes
      {
        title: "official",
        nickname: "dennisreimann",
        email: "mail@dennisreimann.de",
        fullname: "Dennis Reimann",
        postcode: "28199",
        country: "DE",
        language: "DE",
        timezone: "Europe/Berlin",
        gender: "M",
        dob_day: "10",
        dob_month: "01",
        dob_year: "1982",
      }
    end

    def valid_properties
      {
        "nickname" => {"value" => "dennisreimann", "type" => "nickname"},
        "email" => {"value" => "mail@dennisreimann.de", "type" => "email"},
        "gender" => {"value" => "M", "type" => "gender"},
        "dob" => {"value" => "1982-01-10", "type" => "dob"},
        "login" => {"value" => "dennisreimann", "type" => "http://axschema.org/namePerson/friendly"},
        "email_address" => {"value" => "mail@dennisreimann.de", "type" => "http://axschema.org/contact/email"},
      }
    end

    def valid_site_attributes
      {url: "http://dennisreimann.de/"}
    end

    def checkid_request_params
      {
        "openid.ns" => OpenID::OPENID2_NS,
        "openid.mode" => "checkid_setup",
        "openid.realm" => "http://test.com/",
        "openid.trust_root" => "http://test.com/",
        "openid.return_to" => "http://test.com/return",
        "openid.claimed_id" => "http://dennisreimann.de/",
        "openid.identity" => "http://openid.innovated.de/dennisreimann",
      }
    end

    def associate_request_params
      {
        "openid.ns" => OpenID::OPENID2_NS,
        "openid.mode" => "associate",
        "openid.assoc_type" => "HMAC-SHA1",
        "openid.session_type" => "DH-SHA1",
        "openid.dh_consumer_public" => "MgKzyEozjQH6uDumfyCGfDGWW2RM5QRfLi+Yu+h7SuW7l+jxk54/s9mWG+0ZR2J4LmhUO9Cw/sPqynxwqWGQLnxr0wYHxSsBIctUgxp67L/6qB+9GKM6URpv1mPkifv5k1M8hIJTQhzYXxHe+/7MM8BD47vBp0nihjaDr0XAe6w=",
      }
    end

    def sreg_request_params
      {
        "openid.ns.sreg" => OpenID::SReg::NS_URI,
        "openid.sreg.required" => "nickname,email",
        "openid.sreg.optional" => "fullname,dob",
        "openid.sreg.policy_url" => "http://test.com/policy.html",
      }
    end

    def ax_fetch_request_params
      {
        "openid.ns.ax" => OpenID::AX::AXMessage::NS_URI,
        "openid.ax.mode" => OpenID::AX::FetchRequest::MODE,
        "openid.ax.type.nickname" => "http://axschema.org/namePerson/friendly",
        "openid.ax.type.gender" => "http://axschema.org/person/gender",
        "openid.ax.required" => "nickname",
        "openid.ax.if_available" => "gender",
        "openid.ax.update_url" => "http://test.com/update",
      }
    end

    def ax_store_request_params
      {
        "openid.ns.ax" => OpenID::AX::AXMessage::NS_URI,
        "openid.ax.mode" => OpenID::AX::StoreRequest::MODE,
        "openid.ax.count.fullname" => 1,
        "openid.ax.type.fullname" => "http://axschema.org/namePerson",
        "openid.ax.value.fullname.1" => 'Bob "AX Storer" Smith',
        "openid.ax.count.email" => 1,
        "openid.ax.type.email" => "http://axschema.org/contact/email",
        "openid.ax.value.email.1" => "new@axstore.com",
      }
    end

    def pape_request_params
      {
        "openid.ns.pape" => OpenID::PAPE::NS_URI,
        "openid.pape.max_auth_age" => 3600,
        "openid.pape.preferred_auth_policies" => [
          OpenID::PAPE::AUTH_MULTI_FACTOR_PHYSICAL,
          OpenID::PAPE::AUTH_MULTI_FACTOR,
          OpenID::PAPE::AUTH_PHISHING_RESISTANT,
        ].join(" "),
      }
    end

    def assert_valid(object) # just for work with Rails 2.3.4.
      assert(object.valid?)
    end

    def assert_invalid(object, attribute, message = "")
      assert_equal(false, object.valid?)
      assert(object.errors[attribute], message)
    end

    def assert_login_required
      assert_redirected_to(login_path)
      assert_not_nil(request.session[:return_to])
    end

    # verbatim, from ActiveController's own unit tests
    # stolen from http://stackoverflow.com/questions/1165478/testing-http-basic-auth-in-rails-2-2/1258046#1258046
    def encode_credentials(username, password)
      "Basic #{Base64.encode64("#{username}:#{password}")}"
    end

    # Sets the current user in the session from the user fixtures.
    def login_as(account)
      request.session[:account_id] = account ? accounts(account).id : nil
    end

    def authorize_as(account)
      if @request.env["HTTP_AUTHORIZATION"] = account
        ActionController::HttpAuthentication::Basic.encode_credentials(accounts(account).login, "test")
      end
    end
  end
end

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
