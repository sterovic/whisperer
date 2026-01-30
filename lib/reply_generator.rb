class ReplyGenerator
  def initialize
    @client = OpenAI::Client.new(
      api_key: Rails.application.credentials.dig(:openai, :api_key)
    )
  end

  def generate_replies(project:, comment:, video:, num_replies: 1)
    settings = ProjectSettings.new(project)

    system_prompt = build_system_prompt(settings, project)
    user_prompt = build_user_prompt(comment, video, num_replies)

    response = @client.chat.completions.create(
      model: settings.model,
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ],
      temperature: settings.temperature,
      max_tokens: settings.max_tokens,
      response_format: json_response_format
    )

    raw_json = response.choices[0].message.content
    data = JSON.parse(raw_json)

    unless data.is_a?(Hash) && data["replies"].is_a?(Array) && data["replies"].any?
      raise "OpenAI response did not contain a valid 'replies' array"
    end

    data["replies"].map { |r| r["reply"] }
  rescue StandardError => e
    Rails.logger.error "Error calling OpenAI API for replies: #{e.message}"
    raise e
  end

  private

  def build_system_prompt(settings, project)
    custom_prompt = settings.reply_prompt.presence || Project::PROMPT_DEFAULTS[:reply_prompt]

    <<~PROMPT
      #{custom_prompt}

      Product being promoted: #{project.name}
      #{project.description.present? ? "Product description: #{project.description}" : ""}

      Guidelines:
      - Write replies that feel natural and human-like
      - Match the tone of the original comment
      - Keep replies concise (1-3 sentences typically)
      - Don't be overly promotional
      - Sound like a real YouTube user, not a bot
      - Vary your writing style between different replies
      - Avoid emojis unless the original comment uses them
      - Never use em dashes
    PROMPT
  end

  def build_user_prompt(comment, video, num_replies)
    <<~PROMPT
      Generate #{num_replies} different reply(ies) to this YouTube comment.

      Video title: #{video.title}

      Original comment to reply to:
      "#{comment.text}"

      #{comment.author_display_name.present? ? "Comment author: #{comment.author_display_name}" : ""}

      Requirements:
      - Each reply should be unique and feel like it comes from a different person
      - Replies should be relevant to the original comment
      - Keep replies natural and conversational
      - Don't repeat the same points across replies

      Return ONLY valid JSON that matches the schema, with no extra text.
    PROMPT
  end

  def json_response_format
    {
      type: :json_schema,
      json_schema: {
        name: "youtube_replies",
        strict: true,
        schema: {
          type: "object",
          properties: {
            replies: {
              type: "array",
              description: "List of generated YouTube replies.",
              items: {
                type: "object",
                properties: {
                  reply: {
                    type: "string",
                    description: "The reply text, ready to post."
                  }
                },
                required: ["reply"],
                additionalProperties: false
              }
            }
          },
          required: ["replies"],
          additionalProperties: false
        }
      }
    }
  end

  class ProjectSettings
    def initialize(project)
      @project = project
    end

    def method_missing(method_name, *args)
      @project.prompt_setting(method_name)
    end

    def respond_to_missing?(method_name, include_private = false)
      Project::PROMPT_DEFAULTS.key?(method_name.to_sym) || super
    end
  end
end
