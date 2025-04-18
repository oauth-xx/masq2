module Masq
  class ConsumerController < BaseController
    skip_before_action :verify_authenticity_token

    def index
    end

    def start
      begin
        open_id_req = openid_consumer.begin(params[:openid_identifier])
      rescue OpenID::OpenIDError => e
        redirect_to(consumer_path, alert: "Discovery failed for #{params[:openid_identifier]}: #{e}")
        return
      end
      if params[:use_sreg]
        open_id_sreg_req = OpenID::SReg::Request.new
        open_id_sreg_req.policy_url = "http://www.policy-url.com"
        open_id_sreg_req.request_fields(["nickname", "email"], true) # required
        open_id_sreg_req.request_fields(["fullname", "dob"], false) # optional
        open_id_req.add_extension(open_id_sreg_req)
        open_id_req.return_to_args["did_sreg"] = "y"
      end
      if params[:use_ax_fetch]
        axreq = OpenID::AX::FetchRequest.new
        requested_attrs = [
          ["https://openid.tzi.de/spec/schema", "uid", true],
          ["http://axschema.org/namePerson/friendly", "nickname", true],
          ["http://axschema.org/contact/email", "email", true],
          ["http://axschema.org/namePerson", "fullname"],
          ["http://axschema.org/contact/web/default", "website", false, 2],
          ["http://axschema.org/contact/postalCode/home", "postcode"],
          ["http://axschema.org/person/gender", "gender"],
          ["http://axschema.org/birthDate", "birth_date"],
          ["http://axschema.org/contact/country/home", "country"],
          ["http://axschema.org/pref/language", "language"],
          ["http://axschema.org/pref/timezone", "timezone"],
        ]
        requested_attrs.each { |a| axreq.add(OpenID::AX::AttrInfo.new(a[0], a[1], a[2] || false, a[3] || 1)) }
        open_id_req.add_extension(axreq)
        open_id_req.return_to_args["did_ax_fetch"] = "y"
      end
      if params[:use_ax_store]
        ax_store_req = OpenID::AX::StoreRequest.new
        ax_store_req.set_values("http://axschema.org/contact/email", %w(email@example.com))
        ax_store_req.set_values("http://axschema.org/birthDate", %w(1976-08-07))
        ax_store_req.set_values("http://axschema.org/customValueThatIsNotSupported", %w(unsupported))
        open_id_req.add_extension(ax_store_req)
        open_id_req.return_to_args["did_ax_store"] = "y"
      end
      if params[:use_pape]
        open_id_pape_req = OpenID::PAPE::Request.new
        open_id_pape_req.add_policy_uri(OpenID::PAPE::AUTH_PHISHING_RESISTANT)
        open_id_pape_req.max_auth_age = 60
        open_id_req.add_extension(open_id_pape_req)
        open_id_req.return_to_args["did_pape"] = "y"
      end
      if params[:force_post]
        open_id_req.return_to_args["force_post"] = "x" * 2048
      end
      if open_id_req.send_redirect?(consumer_url, consumer_complete_url, params[:immediate])
        redirect_to(open_id_req.redirect_url(consumer_url, consumer_complete_url, params[:immediate]))
      else
        @form_text = open_id_req.form_markup(consumer_url, consumer_complete_url, params[:immediate], {"id" => "checkid_form"})
      end
    end

    def complete
      parameters = params.to_unsafe_h.reject { |k, _v| request.path_parameters[k.to_sym] }
      open_id_req = openid_consumer.complete(parameters, url_for({}))
      case open_id_req.status
      when OpenID::Consumer::SETUP_NEEDED
        flash[:alert] = t(:immediate_request_failed_setup_needed)
      when OpenID::Consumer::CANCEL
        flash[:alert] = t(:openid_transaction_cancelled)
      when OpenID::Consumer::FAILURE
        flash[:alert] = open_id_req.display_identifier ?
          t(:verification_of_identifier_failed, identifier: open_id_req.display_identifier, message: open_id_req.message) :
          t(:verification_failed_message, message: open_id_req.message)
      when OpenID::Consumer::SUCCESS
        flash[:notice] = t(:verification_of_identifier_succeeded, identifier: open_id_req.display_identifier)
        if params[:did_sreg]
          sreg_resp = OpenID::SReg::Response.from_success_response(open_id_req)
          sreg_message = "\n\n" + t(:simple_registration_data_requested)
          if sreg_resp.empty?
            sreg_message << ", " + t(:but_none_was_returned)
          else
            sreg_message << ". " + t(:the_following_data_were_sent) + "\n"
            sreg_resp.data.each { |k, v| sreg_message << "#{k}: #{v}\n" }
          end
          flash[:notice] += sreg_message
        end
        if params[:did_ax_fetch]
          ax_fetch_resp = OpenID::AX::FetchResponse.from_success_response(open_id_req)
          ax_fetch_message = "\n\n" + t(:attribute_exchange_data_requested)
          if ax_fetch_resp
            ax_fetch_message << ". " + t(:the_following_data_were_sent) + "\n"
            ax_fetch_resp.data.each { |k, v| ax_fetch_message << "#{k}: #{v}\n" }
          else
            ax_fetch_message << ", " + t(:but_none_was_returned)
          end
          flash[:notice] += ax_fetch_message
        end
        if params[:did_ax_store]
          ax_store_resp = OpenID::AX::StoreResponse.from_success_response(open_id_req)
          ax_store_message = "\n\n" + t(:attribute_exchange_store_requested)
          ax_store_message << if ax_store_resp
            if ax_store_resp.succeeded?
              " " + t(:and_saved_at_the_identity_provider)
            else
              ", " + t(:but_an_error_occured, error_message: ax_store_resp.error_message)
            end
          else
            ", " + t(:but_got_no_response)
          end
          flash[:notice] += ax_store_message
        end
        if params[:did_pape]
          pape_resp = OpenID::PAPE::Response.from_success_response(open_id_req)
          pape_message = "\n\n" + t(:authentication_policies_requested)
          if pape_resp.auth_policies.empty?
            pape_message << ", " + t(:but_the_server_did_not_report_one)
          else
            pape_message << ", " + t(:and_server_reported_the_following) + "\n"
            pape_resp.auth_policies.each { |p| pape_message << "#{p}\n" }
          end
          pape_message << "\n" + t(:authentication_time) + ": #{pape_resp.auth_time}" if pape_resp.auth_time
          pape_message << "\nNIST Auth Level: #{pape_resp.nist_auth_level}" if pape_resp.nist_auth_level
          flash[:notice] += pape_message
        end
      else
        # NOOP
        # This should never happen.
      end
      redirect_to(action: "index")
    end

    private

    # OpenID consumer reader, used to access the consumer functionality
    def openid_consumer
      @openid_consumer ||= OpenID::Consumer.new(session, ActiveRecordStore.new)
    end
  end
end
