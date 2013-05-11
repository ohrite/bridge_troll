require 'spec_helper'

describe RsvpSession do
  it { should allow_mass_assignment_of(:event_session_id) }
  it { should allow_mass_assignment_of(:checked_in) }
  it { should allow_mass_assignment_of(:rsvp_id) }
  it { should allow_mass_assignment_of(:rsvp) }

  context 'checkins counter cache' do
    let(:rsvp) { create(:rsvp) }
    let!(:session1) { create(:rsvp_session, rsvp: rsvp) }
    let!(:session2) { create(:rsvp_session, rsvp: rsvp) }

    it "counts the number of checkins" do
      rsvp.checkins_count.should == 0

      expect {
        session1.checked_in = true
        session1.save!
      }.to change { rsvp.reload.checkins_count }.by(1)

      expect {
        session2.checked_in = true
        session2.save!
      }.to change { rsvp.reload.checkins_count }.by(1)

      expect {
        session1.destroy
      }.to change { rsvp.reload.checkins_count }.by(-1)
    end
  end
end
