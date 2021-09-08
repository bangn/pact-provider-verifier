require 'pact/provider_verifier/app'

module Pact
  module ProviderVerifier
    describe App do
      # I do not understand why, but if this spec runs in the same scope as the other tests, it causes this error:
      #  got #<NoMethodError: undefined method `strip' for nil:NilClass> with backtrace:
      #   /.gem/ruby/2.2.2/gems/faraday-0.17.3/lib/faraday/adapter/net_http.rb:67:in `new'
      #   /.gem/ruby/2.2.2/gems/faraday-0.17.3/lib/faraday/adapter/net_http.rb:67:in `create_request'
      # Don't have time to investigate now - just running it separately
      describe "call", run_separately: true do
        before do
          allow(AggregatePactConfigs).to receive(:call).and_return([])
          allow(Cli::RunPactVerification).to receive(:call)
          allow(Pact).to receive(:clear_configuration)
          allow(Pact).to receive(:clear_consumer_world)
          allow(Pact).to receive(:clear_provider_world)
          allow_any_instance_of(App).to receive(:wait_until_server_available).and_return(true)
          allow($stderr).to receive(:puts)
          allow(Git).to receive(:branch)
        end

        let(:options) do
          double('options',
            provider_base_url: "http://provider",
            provider_version_tag: ["foo"],
            publish_verification_results: false,
            wait: 1,
            provider_states_url: nil,
            log_level: :info,
            log_dir: 'tmp'
            ).as_null_object
        end

        let(:pact_urls) { ["http://pact"] }

        subject { App.call(pact_urls, options) }

        context "when tag_with_git_branch is true" do
          before do
            allow(Git).to receive(:branch).and_return("master")
          end

          it "merges the git branch with any specified provider tags" do
            # This is a shitty way to test the provider tags, but it's easier than checking
            # that the pact configuration DSL is called the right way!
            expect(AggregatePactConfigs).to receive(:call).with(
              anything,
              anything,
              anything,
              anything,
              anything,
              ["foo", "master"],
              anything,
              anything,
              anything
            )
            subject
          end
        end

        context "when fail_if_no_pacts_found is false" do
          before do
            allow(options).to receive(:fail_if_no_pacts_found).and_return(false)
          end

          context "when no pacts are found" do
            before do
              allow(AggregatePactConfigs).to receive(:call).and_return([])
            end

            it { is_expected.to be true }
          end
        end

        context "when fail_if_no_pacts_found is true" do
          before do
            allow(options).to receive(:fail_if_no_pacts_found).and_return(true)
          end

          context "when no pacts are found" do
            before do
              allow(AggregatePactConfigs).to receive(:call).and_return([])
            end

            it { is_expected.to be false }
          end

          context "when pacts are found and successfully verified" do
            before do
              allow(AggregatePactConfigs).to receive(:call).and_return([{}])
              allow(Cli::RunPactVerification).to receive(:call).and_return(0)
            end

            it { is_expected.to be true }
          end
        end

        context "multiple pacts need to be verified" do
          before do
            allow(AggregatePactConfigs).to receive(:call).and_return([{}, {}])
          end

          context "at least one pact fails verification" do
            before do
              allow(Cli::RunPactVerification).to receive(:call).and_return(1)
            end

            it "all pacts get verified" do
              expect(Cli::RunPactVerification).to receive(:call).twice
              subject
            end
          end
        end
      end
    end
  end
end
