class MessagesController < ApplicationController
  before_action :require_logged_in_user
  before_action :find_message, only: [:show, :destroy, :keep_as_new]

  def index
    @cur_url = "/messages"
    @title = I18n.t "controllers.messages_controller.messagestitle"

    @new_message = Message.new

    @direction = :in
    @messages = @user.undeleted_received_messages

    if params[:to]
      @new_message.recipient_username = params[:to]
    end
  end

  def sent
    @cur_url = "/messages"
    @title = I18n.t "controllers.messages_controller.messagessenttitle"

    @direction = :out
    @messages = @user.undeleted_sent_messages

    @new_message = Message.new

    render action: "index"
  end

  def create
    @cur_url = "/messages"
    @title = "Messages"

    @new_message = Message.new(message_params)
    @new_message.author_user_id = @user.id

    @direction = :out
    @messages = @user.undeleted_received_messages

    if @new_message.save
      flash[:success] = I18n.t "controllers.messages_controller.flashmsgsentto", user: @new_message.recipient.username.to_s
      redirect_to "/messages"
    else
      render action: "index"
    end
  end

  def show
    @cur_url = "/messages"
    @title = @message.subject

    if @message.author
      @new_message = Message.new
      @new_message.recipient_username = ((@message.author_user_id == @user.id) ?
        @message.recipient.username : @message.author.username)

      @new_message.subject = if /^re:/i.match?(@message.subject)
        @message.subject
      else
        "Re: #{@message.subject}"
      end
    end

    if @message.recipient_user_id == @user.id
      @message.has_been_read = true
      @message.save
    end
  end

  def destroy
    if @message.author_user_id == @user.id
      @message.deleted_by_author = true
    end

    if @message.recipient_user_id == @user.id
      @message.deleted_by_recipient = true
    end

    @message.save!

    flash[:success] = I18n.t "controllers.messages_controller.flashdeletedmessage"

    if @message.author_user_id == @user.id
      redirect_to "/messages/sent"
    else
      redirect_to "/messages"
    end
  end

  def batch_delete
    deleted = 0

    params.each do |k, v|
      if v.to_s == "1" && (m = k.match(/^delete_(.+)$/))
        if (message = Message.where(short_id: m[1]).first)
          ok = false
          if message.author_user_id == @user.id
            message.deleted_by_author = true
            ok = true
          end
          if message.recipient_user_id == @user.id
            message.deleted_by_recipient = true
            ok = true
          end

          if ok
            message.save!
            deleted += 1
          end
        end
      end
    end

    flash[:success] = I18n.t "controllers.messages_controller.flashdelmsg", nbmsg: deleted.to_s, plural: ("s" unless deleted == 1).to_s

    @user.update_unread_message_count!

    redirect_to "/messages"
  end

  def keep_as_new
    @message.has_been_read = false
    @message.save

    redirect_to "/messages"
  end

  private

  def message_params
    params.require(:message).permit(
      :recipient_username, :subject, :body
    )
  end

  def find_message
    if (@message = Message.where(short_id: params[:message_id] ||
    params[:id]).first)
      if @message.author_user_id == @user.id ||
          @message.recipient_user_id == @user.id
        return true
      end
    end

    flash[:error] = I18n.t "controllers.messages_controller.flashcannotfindmsg"
    redirect_to "/messages"
    false
  end
end
