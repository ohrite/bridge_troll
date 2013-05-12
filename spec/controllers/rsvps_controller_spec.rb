require 'spec_helper'

describe RsvpsController do
  before do
    @event = create(:event, title: 'The Best Railsbridge')
  end

  describe "when signed in" do
    before do
      @user = create(:user)
      sign_in @user
    end

    describe "#volunteer" do
      it "creates an RSVP for the volunteer role" do
        get :volunteer, event_id: @event.id
        assigns(:rsvp).role.should == Role::VOLUNTEER
      end
    end

    describe "#learn" do
      it "creates an RSVP for the student role" do
        get :learn, event_id: @event.id
        assigns(:rsvp).role.should == Role::STUDENT
      end
    end
  end

  describe "#create" do
    context "without logging in, I am redirected from the page" do
      it "redirects to the sign in page" do
        assigns[:current_user].should be_nil
        post :create, event_id: @event.id, rsvp: @rsvp_params
        response.should redirect_to("/users/sign_in")
      end

      it "does not create any new rsvps" do
        expect {
          post :create, event_id: @event.id, rsvp: @rsvp_params
        }.to_not change { Rsvp.count }
      end
    end

    context "when there is no rsvp for the volunteer/event" do
      before do
        @user = create(:user)
        sign_in @user
        @rsvp_params = {
          role_id: Role::VOLUNTEER.id,
          teaching_experience: "i love ducks so much",
          subject_experience: "oh but i also love geese",
          rsvp_sessions: [
            @event.event_sessions.first.id
          ]
        }
      end

      it "should allow the user to newly volunteer for an event" do
        expect {
          post :create, event_id: @event.id, rsvp: @rsvp_params
        }.to change { Rsvp.count }.by(1)
      end

      it "redirects to the event page related to the rsvp with flash confirmation" do
        post :create, event_id: @event.id, rsvp: @rsvp_params
        response.should redirect_to(event_path(@event))
        flash[:notice].should match(/thanks/i)
      end

      it "should create a rsvp that persists and is valid" do
        post :create, event_id: @event.id, rsvp: @rsvp_params
        assigns[:rsvp].should be_persisted
        assigns[:rsvp].should be_valid
      end

      it "should set the new rsvp with the selected event, and current user" do
        post :create, event_id: @event.id, rsvp: @rsvp_params
        assigns[:rsvp].user_id.should == assigns[:current_user].id
        assigns[:rsvp].event_id.should == @event.id
      end

      context "when the event has some volunteers" do
        before do
          @event.update_attribute(:student_rsvp_limit, 2)
          create(:volunteer_rsvp, event: @event)
          create(:volunteer_rsvp, event: @event)
        end

        it "adds the newly rsvp'd user as a confirmed user" do
          post :create, event_id: @event.id, rsvp: @rsvp_params
          rsvp = Rsvp.last
          rsvp.waitlist_position.should be_nil
        end
      end

      context "when the event is full of students" do
        before do
          @event.update_attribute(:student_rsvp_limit, 2)
          create(:student_rsvp, event: @event)
          create(:student_rsvp, event: @event)
        end

        it "adds the newly rsvp'd user to the waitlist" do
          post :create, event_id: @event.id, rsvp: @rsvp_params
          rsvp = Rsvp.last
          rsvp.waitlist_position.should == 1
        end
      end

      context "when the event is full and has a waitlist" do
        before do
          @event.update_attribute(:student_rsvp_limit, 2)
          create(:student_rsvp, event: @event)
          create(:student_rsvp, event: @event)
          create(:student_rsvp, event: @event, waitlist_position: 1)
        end

        it "adds the newly rsvp'd user to the waitlist" do
          post :create, event_id: @event.id, rsvp: @rsvp_params
          rsvp = Rsvp.last
          rsvp.waitlist_position.should == 2
        end
      end

      describe "childcare information" do
        context "when childcare_needed is unchecked" do
          before do
            post :create, event_id: @event.id, rsvp: @rsvp_params.merge(
              needs_childcare: '0', childcare_info: 'goodbye, cruel world')
          end
          it "should clear childcare_info" do
            assigns[:rsvp].childcare_info.should be_blank
          end
        end

        context "when childcare_needed is checked" do
          it "should has validation errors for blank childcare_info" do
            post :create, event_id: @event.id, rsvp: @rsvp_params.merge(
              needs_childcare: '1',
              childcare_info: ''
            )
            assigns[:rsvp].should have(1).errors_on(:childcare_info)
          end

          it "updates sets childcare_info when not blank" do
            child_info = "Johnnie Kiddo, 7\nJane Kidderino, 45"
            post :create, event_id: @event.id, rsvp: @rsvp_params.merge(
              needs_childcare: '1',
              childcare_info: child_info
            )
            assigns[:rsvp].childcare_info.should == child_info
          end
        end
      end
    end

    context "when there is already a rsvp for the volunteer/event" do
      #the user may have canceled, changed his/her mind, and decided to volunteer again
      before do
        @user = create(:user)
        sign_in @user
        @rsvp = create(:rsvp, user: @user, event: @event)
        @rsvp_params = {
          role_id: Role::VOLUNTEER.id,
          teaching_experience: "i love ducks so much",
          subject_experience: "oh but i also love geese",
          rsvp_sessions: [
            @event.event_sessions.first.id
          ]
        }
      end

      it "does not create any new rsvps" do
        expect {
          post :create, event_id: @event.id, rsvp: @rsvp_params
        }.to_not change { Rsvp.count }
      end
    end
  end

  describe "#destroy" do
    before do
      @user = create(:user)
      sign_in @user
    end

    context "when there is an existing rsvp" do
      before do
        @rsvp = create(:rsvp)
      end

      it "should destroy the rsvp" do
        expect {
          delete :destroy, event_id: @rsvp.event.id, id: @rsvp.id
        }.to change { Rsvp.count }.by(-1)

        expect {
          @rsvp.reload
        }.to raise_error(ActiveRecord::RecordNotFound)

        flash[:notice].should match(/no longer signed up/i)
      end

      it "should reorder the waitlist" do
        Event.should_receive(:find_by_id).and_return(@rsvp.event)
        @rsvp.event.should_receive(:reorder_waitlist!)
        delete :destroy, event_id: @rsvp.event.id, id: @rsvp.id
      end
    end

    context "when there is no RSVP for this user" do
      it "should notify the user s/he has not signed up to volunteer for the event" do
        expect {
          delete :destroy, event_id: 3298423, id: 29101
        }.to change { Rsvp.count }.by(0)
        flash[:notice].should match(/You are not signed up/i)
      end
    end
  end
end
