

class ShiftQuestionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_shift_question, only: %i[edit update destroy]

  def index
    @shift_questions = ShiftQuestion.ordered
  end

  def new
    @shift_question = ShiftQuestion.new(question_type: ShiftQuestion::QUESTION_TYPES[:PRE_SHIFT], display_order: 0)
  end

  def create
    @shift_question = ShiftQuestion.new(shift_question_params)
    if @shift_question.save
      redirect_to shift_questions_path, notice: "Question created."
    else
      flash.now[:alert] = @shift_question.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @shift_question.update(shift_question_params)
      redirect_to shift_questions_path, notice: "Question updated."
    else
      flash.now[:alert] = @shift_question.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shift_question.destroy
    redirect_to shift_questions_path, notice: "Question deleted."
  end

  private

  def set_shift_question
    @shift_question = ShiftQuestion.find(params[:id])
  end

  def shift_question_params
    params.require(:shift_question).permit(:question_text, :question_type, :display_order, :is_mandatory, :is_active)
  end
end
