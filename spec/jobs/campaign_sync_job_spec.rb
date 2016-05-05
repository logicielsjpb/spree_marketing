require 'spec_helper'

RSpec.describe CampaignSyncJob, type: :job do
  include ActiveJob::TestHelper

  SpreeMarketing::CONFIG ||= { Rails.env => {} }

  class GibbonServiceTest
    attr_accessor :campaigns, :recipients
  end

  let(:list) { create(:marketing_list) }
  let(:since_send_time) { (Time.current - 1.day).to_s }
  let(:gibbon_service) { GibbonServiceTest.new }
  let(:campaigns_data) { [{ id: '12456', type: 'regular', settings: { title: 'test' },
      recipients: { list_id: list.uid }, send_time: Time.current.to_s }.with_indifferent_access] }
  let(:contact) { create(:marketing_contact) }
  let(:recipients_data) { [{ email_id: contact.uid, email_address: contact.email, status: 'sent' }.with_indifferent_access] }

  before do
    allow(GibbonService::CampaignService).to receive(:new).and_return(gibbon_service)
    allow(gibbon_service).to receive(:retrieve_sent_campaigns).and_return(gibbon_service)
    allow(gibbon_service).to receive(:campaigns).and_return(campaigns_data)
    allow(gibbon_service).to receive(:retrieve_recipients).and_return(gibbon_service)
    allow(gibbon_service).to receive(:recipients).and_return(recipients_data)
  end

  subject(:job) { described_class.perform_later(since_send_time) }

  it 'queues the job' do
    expect { job }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
  end

  it 'creates campaigns' do
    perform_enqueued_jobs { job }
    expect(Spree::Marketing::Campaign.first.uid).to eq(campaigns_data.first[:id])
  end

  it 'adds recipients to generated campaigns' do
    perform_enqueued_jobs { job }
    expect(Spree::Marketing::Campaign.first.recipients).not_to be_nil
  end

  it 'is in default queue' do
    expect(CampaignSyncJob.new.queue_name).to eq('default')
  end

  context 'executes perform' do
    it { expect(GibbonService::CampaignService).to receive(:new).and_return(gibbon_service) }
    it { expect(gibbon_service).to receive(:retrieve_sent_campaigns).with(since_send_time).and_return(gibbon_service) }
    it { expect(gibbon_service).to receive(:campaigns).and_return(campaigns_data) }
    it { expect(gibbon_service).to receive(:retrieve_recipients).and_return(gibbon_service) }
    it { expect(gibbon_service).to receive(:recipients).and_return(recipients_data) }

    after { perform_enqueued_jobs { job } }
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end
end
