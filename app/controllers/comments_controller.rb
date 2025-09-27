class CommentsController < ApplicationController
  include ActionView::RecordIdentifier
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_commentable, only: [:index, :create]
  before_action :set_comment, only: [:edit, :update, :remove_file, :destroy]

  def index
    # Last 5 newest, then display ASC
    scope = @commentable.comments.order(created_at: :desc, id: :desc)
    if params[:before_id].present?
      pivot = @commentable.comments.find_by(id: params[:before_id])
      if pivot
        scope = scope.where("(created_at < ?) OR (created_at = ? AND id < ?)", pivot.created_at, pivot.created_at, pivot.id)
      end
    end
    @comments = scope.limit(5).to_a
    @comments_for_display = @comments.reverse

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back(fallback_location: root_path) }
    end
  end

  def create
    @comment = @commentable.comments.build(comment_params.merge(user: current_user))
    files_selected = Array(params.dig(:comment, :files)).reject(&:blank?).any?
    if @comment.body.to_s.strip.blank? && !files_selected
      @comment.errors.add(:base, "Please add a comment or attach a file.")
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@commentable, :comments_errors), @comment.errors.full_messages.to_sentence), status: :unprocessable_entity }
        format.html { redirect_back(fallback_location: root_path, alert: @comment.errors.full_messages.to_sentence) }
      end and return
    end
    if @comment.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back(fallback_location: root_path) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@commentable, :comments_errors), @comment.errors.full_messages.to_sentence), status: :unprocessable_entity }
        format.html { redirect_back(fallback_location: root_path, alert: @comment.errors.full_messages.to_sentence) }
      end
    end
  end

  def edit
    render :edit
  end

  def update
    # Keep existing files unless new ones are explicitly added; do not overwrite attachments
    files_param = Array(params.dig(:comment, :files)).reject(&:blank?)
    @comment.assign_attributes(comment_params.except(:files))
    @comment.edited_at = Time.current
    @comment.edited_by = current_user
    if @comment.save
      if files_param.any?
        @comment.files.attach(files_param)
      end
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back(fallback_location: root_path) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@comment, :errors), @comment.errors.full_messages.to_sentence), status: :unprocessable_entity }
        format.html { redirect_back(fallback_location: root_path, alert: @comment.errors.full_messages.to_sentence) }
      end
    end
  end

  def remove_file
    signed_id = params[:signed_id].to_s
    if signed_id.present?
      blob = ActiveStorage::Blob.find_signed(signed_id) rescue nil
      if blob
        attachment = @comment.files.attachments.find { |att| att.blob_id == blob.id }
        attachment&.purge
      end
    end
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(dom_id(@comment)) { render_to_string(:edit) }
      end
      format.html { redirect_back(fallback_location: root_path) }
    end
  end

  def destroy
    @comment.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id(@comment)) }
      format.html { redirect_back(fallback_location: root_path, notice: 'Comment deleted.') }
    end
  end

  private
  def require_admin!
    redirect_to root_path, alert: "Unauthorized" unless current_user&.admin?
  end

  def set_commentable
    @commentable = if params[:user_id]
      User.find(params[:user_id])
    elsif params[:location_id]
      Location.find(params[:location_id])
    else
      raise ActiveRecord::RecordNotFound, "Unknown commentable"
    end
  end

  def set_comment
    @comment = Comment.find(params[:id])
    @commentable = @comment.commentable
  end

  def comment_params
    params.require(:comment).permit(:body, files: [])
  end
end
