module Courses
  class InfectionControlController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_user
    before_action :set_step

    COURSE_SLUG = 'infection_control'.freeze
    PASS_SCORE = 5

    def show
      @modules = modules_content

      case @step
      when 10
        @completion = current_user.course_completion_for(COURSE_SLUG)
        redirect_to courses_infection_control_path(step: 1), alert: "Please complete the quiz first." and return unless @completion&.passed?
      when 9
        @questions = quiz_questions
      else
        @content = @modules[@step - 1]
        redirect_to courses_infection_control_path(step: 1) and return unless @content
      end
    end

    def submit_quiz
      answers = [quiz_params[:q1], quiz_params[:q2], quiz_params[:q3], quiz_params[:q4], quiz_params[:q5]]
      unless quiz_params[:acknowledgement] == 'yes'
        redirect_to courses_infection_control_path(step: 9), alert: "Please acknowledge your responsibilities before submitting." and return
      end
      score = grade_quiz(answers)

      completion = current_user.course_completion_for(COURSE_SLUG) || current_user.course_completions.build(course_slug: COURSE_SLUG)
      completion.score = score
      completion.passed = score >= PASS_SCORE
      completion.completed_at = Time.current if completion.passed?
      completion.save!

      if completion.passed?
        redirect_to courses_infection_control_path(step: 10), notice: "Great work! You passed the quiz."
      else
        redirect_to courses_infection_control_path(step: 9), alert: "Score #{score}/#{quiz_questions.size}. Review the modules and try again."
      end
    end

    private

    def authorize_user
      unless current_user.admin? || current_user.manager? || current_user.employee?
        redirect_to root_path, alert: "You are not authorised to view that course."
      end
    end

    def set_step
      @step = params[:step].to_i
      @step = 1 if @step < 1
    end

    def modules_content
      [
        {
          title: "Module 1: Introduction to Infection Prevention and Control",
          emoji: "🏁",
          objective: "To understand what infection prevention and control means, why it’s essential, and your role as an NDIS support worker.",
          paragraphs: [
            "Infection Prevention and Control (IPC) is a set of practices that help prevent the spread of infection in healthcare and community settings.",
            "Support workers often assist people with disability in their homes and community — these environments require awareness of infection risks.",
            "Following IPC procedures protects participants, workers, and the wider community."
          ],
          activity: "Reflect on a time you helped a participant who was unwell. What steps did you take to keep everyone safe?"
        },
        {
          title: "Module 2: Understanding How Infections Spread",
          emoji: "🦠",
          objective: "Learn how infections are transmitted and what can be done to break the chain.",
          paragraphs: [
            "Infections spread through the Chain of Infection: Pathogen, Reservoir, Exit, Transmission, Entry, Susceptible host.",
            "If you break any link in the chain, infection stops spreading.",
            "Example: Using gloves and washing hands after assisting with personal care breaks the transmission link."
          ]
        },
        {
          title: "Module 3: Hand Hygiene",
          emoji: "🧴",
          objective: "To perform correct hand hygiene to prevent infection transmission.",
          paragraphs: [
            "Wash hands before and after direct contact with a participant, before preparing food, after using the bathroom, coughing, sneezing, touching waste, and after removing gloves.",
            "Steps for hand washing: wet hands and apply soap; rub palms, backs, between fingers, around thumbs, fingertips; rinse and dry with a clean towel.",
            "If using sanitiser: use 60–80% alcohol and rub until dry."
          ]
        },
        {
          title: "Module 4: Personal Protective Equipment (PPE)",
          emoji: "😷",
          objective: "Understand when and how to use PPE safely.",
          paragraphs: [
            "Common PPE includes gloves, masks, gowns/aprons, and eye protection.",
            "Tips: check for damage before use, remove and dispose safely, change PPE between participants or tasks.",
            "Example: wear gloves for personal hygiene; wear a mask near respiratory symptoms."
          ]
        },
        {
          title: "Module 5: Cleaning and Disinfection",
          emoji: "🧹",
          objective: "Learn how to maintain a safe, hygienic environment.",
          paragraphs: [
            "Use cleaning products according to manufacturer instructions.",
            "Clean from clean to dirty areas and frequently clean high-touch surfaces.",
            "Use colour-coded cloths and always wear gloves when cleaning." 
          ]
        },
        {
          title: "Module 6: Waste Management and Laundry",
          emoji: "♻️",
          objective: "Dispose of waste safely and handle laundry hygienically.",
          paragraphs: [
            "Separate general and clinical waste, use lined bins with lids, avoid overfilling, wash hands after handling waste.",
            "Laundry: use gloves for soiled items, wash at highest suitable temperature, dry items completely."
          ]
        },
        {
          title: "Module 7: If You’re Sick or Exposed",
          emoji: "🤒",
          objective: "Understand reporting and exclusion responsibilities.",
          paragraphs: [
            "Do not attend work if unwell; notify supervisor and follow policy.",
            "Report any exposure to infectious materials immediately.",
            "Follow Queensland Health and NDIS infection control guidance."
          ],
          resource: "Queensland Health – Infection Control Guidelines"
        },
        {
          title: "Module 8: NDIS Practice Standards",
          emoji: "✅",
          objective: "Understand compliance obligations under the NDIS.",
          paragraphs: [
            "Providers must minimise infection risks and ensure workers are trained.",
            "Worker duties: follow policies, participate in training, report risks immediately." 
          ],
          resource: "NDIS Quality and Safeguards Commission – Infection Prevention and Control"
        }
      ]
    end

    def quiz_questions
      [
        {
          prompt: "What are the 5 moments for hand hygiene?",
          options: [
            { value: "five_moments", text: "Before touching a participant, before a task, after bodily fluid exposure, after touching a participant, after touching surroundings" },
            { value: "before_meals", text: "Before meals, after meals, before bedtime" },
            { value: "after_shift", text: "Only after finishing your shift or using the bathroom" }
          ],
          correct_value: "five_moments"
        },
        {
          prompt: "When should gloves be worn?",
          options: [
            { value: "personal_care", text: "During personal care, contact with bodily fluids, or when cleaning" },
            { value: "outdoors", text: "Whenever working outdoors regardless of the task" },
            { value: "desk_work", text: "Only when doing paperwork or computer work" }
          ],
          correct_value: "personal_care"
        },
        {
          prompt: "Which of the following are high-touch surfaces?",
          options: [
            { value: "doorknobs", text: "Doorknobs, light switches, mobility aids" },
            { value: "ceiling", text: "Ceiling fixtures and skylights" },
            { value: "floor", text: "Floors under furniture" }
          ],
          correct_value: "doorknobs"
        },
        {
          prompt: "What should you do if you develop symptoms of illness?",
          options: [
            { value: "report_and_stay_home", text: "Stay home, report it, and follow company policy" },
            { value: "take_painkillers", text: "Take over-the-counter medicine and continue working" },
            { value: "ignore", text: "Ignore symptoms unless they last more than two weeks" }
          ],
          correct_value: "report_and_stay_home"
        },
        {
          prompt: "Why is PPE important?",
          options: [
            { value: "protects", text: "It protects workers and participants by preventing infection spread" },
            { value: "fashion", text: "It keeps workers looking professional" },
            { value: "storage", text: "It provides extra pockets for equipment" }
          ],
          correct_value: "protects"
        }
      ]
    end

    def quiz_params
      params.require(:quiz).permit(:q1, :q2, :q3, :q4, :q5, :acknowledgement)
    end

    def grade_quiz(answers)
      questions = quiz_questions

      answers.each_with_index.reduce(0) do |score, (answer, idx)|
        expected = questions[idx][:correct_value]
        score + (answer.present? && answer == expected ? 1 : 0)
      end
    end
  end
end
