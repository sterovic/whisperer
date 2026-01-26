class CommentGenerator
  DEFAULT_MODEL = "gpt-4o-mini"

  def initialize
    @client = OpenAI::Client.new(
      api_key: Rails.application.credentials.dig(:openai, :api_key)
    )
  end

  # New interface: accepts project and video objects
  def generate_comments(project:, video:, num_comments: nil)
    settings = ProjectSettings.new(project)
    num = num_comments || settings.num_comments

    # Fetch existing comments if enabled
    existing_comments = []
    if settings.include_existing_comments
      existing_comments = fetch_video_comments(video.youtube_id)
    end

    system_prompt = build_system_prompt(
      settings: settings,
      product_name: project.name,
      product_description: project.description
    )

    user_prompt = build_user_prompt(
      settings: settings,
      product_name: project.name,
      video: video,
      existing_comments: existing_comments,
      num_comments: num
    )

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

    unless data.is_a?(Hash) && data["comments"].is_a?(Array) && data["comments"].any?
      raise "OpenAI response did not contain a valid 'comments' array"
    end

    data["comments"].map { |c| c["comment"] }
  rescue StandardError => e
    Rails.logger.error "Error calling OpenAI API: #{e.message}"
    raise e
  end

  # Legacy interface for backwards compatibility
  def generate_comments_legacy(
    product_name:,
    product_description:,
    title:,
    description: nil,
    comments: [],
    desired_length: "medium",
    mention_product: true,
    num_comments: 10
  )
    system_prompt = build_legacy_system_prompt(product_name: product_name, product_description: product_description)
    user_prompt = build_legacy_user_prompt(
      product_name: product_name,
      title: title,
      description: description,
      comments: comments,
      desired_length: desired_length,
      mention_product: mention_product,
      num_comments: num_comments
    )

    response = @client.chat.completions.create(
      model: DEFAULT_MODEL,
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ],
      temperature: 0.9,
      max_tokens: 1000,
      response_format: json_response_format
    )

    raw_json = response.choices[0].message.content
    data = JSON.parse(raw_json)

    unless data.is_a?(Hash) && data["comments"].is_a?(Array) && data["comments"].any?
      raise "OpenAI response did not contain a valid 'comments' array"
    end

    data["comments"].map { |c| c["comment"] }
  rescue StandardError => e
    Rails.logger.error "Error calling OpenAI API: #{e.message}"
    []
  end

  private

  def fetch_video_comments(youtube_id, limit: 6)
    video = Yt::Video.new(id: youtube_id)
    video.comment_threads.take(limit).map { |c| c.text_display }
  rescue => e
    Rails.logger.warn "Failed to fetch comments for video #{youtube_id}: #{e.message}"
    []
  end

  def build_system_prompt(settings:, product_name:, product_description:)
    tone_instruction = case settings.tone
                       when "casual"
                         "Sound like an average commenter, not a brand or marketer. Use casual, everyday language."
                       when "friendly"
                         "Be warm and friendly, like talking to a friend. Supportive and positive."
                       when "enthusiastic"
                         "Show genuine excitement and enthusiasm about the topic. Use exclamations sparingly."
                       when "professional"
                         "Be professional and articulate, but not corporate. Think informed viewer."
                       when "witty"
                         "Be clever and witty. Use humor and wordplay when appropriate."
                       when "sarcastic"
                         "Be mildly sarcastic and edgy, but not mean-spirited."
                       else
                         "Sound like an average commenter, not a brand or marketer."
                       end

    additional = settings.additional_instructions.presence || ""

    prompt = <<~PROMPT
      You are a YouTube commenter promoting a product called #{product_name}.

      Product description:
      #{product_description.presence || "(No description)"}

      #{additional.present? ? "Additional instructions:\n#{additional}\n" : ""}

      #{tone_instruction}
    PROMPT

    prompt.gsub("{product_name}", product_name)
          .gsub("{product_description}", product_description)
  end

  def build_user_prompt(settings:, product_name:, video:, existing_comments:, num_comments:)
    sections = []

    sections << "Generate #{num_comments} different YouTube comments for this video."
    sections << ""
    sections << "Requirements:"
    sections << "- All comments must feel distinct from each other (not just tiny wording changes)."
    sections << "- Respect the preferences below for length, language and #{product_name} mentioning."
    sections << "- Each comment should be independently postable on the video."
    sections << ""

    if settings.include_video_title
      sections << "Video title:"
      sections << video.title.to_s
      sections << ""
    end

    if settings.include_video_description
      desc = video.description.to_s.strip
      sections << "Video description:"
      sections << (desc.empty? ? "[no description]" : desc.truncate(500))
      sections << ""
    end

    if settings.include_existing_comments && existing_comments.any?
      formatted = existing_comments.first(6).map { |c| "- #{c}" }.join("\n")
      sections << "Example comments from this video:"
      sections << formatted
      sections << ""
    end

    sections << "Preferences:"
    sections << "- desired_length: #{settings.comment_length}"
    sections << "- mention_product: #{settings.mention_product}"
    sections << ""
    sections << "Return ONLY valid JSON that matches the schema, with no extra text."

    sections.join("\n")
  end

  def build_legacy_system_prompt(product_name:, product_description:)
    <<~PROMPT
      You are an assistant that writes YouTube comments for a human user.
      Your job is to write one or more YouTube comments for a given video.

      About #{product_name}:
      #{product_description}

      Style rules:
      - Sound like an average commenter, not a brand or marketer.
      - Use casual, everyday language. Some light slang and small grammar imperfections are okay.
      - Do NOT be overly formal, inspirational, or like a professional copywriter.
      - The comments should feel like they fit naturally among existing comments.
      - If example comments are provided, loosely match their vibe and length range.
      - When `mention_product` is true, each comment should mention #{product_name} exactly once,
        in a subtle, natural way (like a side remark or tip), not an ad or hard promo.
      - Avoid emojis most of the time. They are allowed, but use them very sparingly.
      - Never use em dashes. Use normal punctuation instead.
      - Always follow the JSON schema given in response_format.
        The `comments` array must always be present, and each item must contain `comment`.
    PROMPT
  end

  def build_legacy_user_prompt(product_name:, title:, description:, comments:, desired_length:, mention_product:, num_comments:)
    comments_section =
      if comments&.any?
        formatted = comments.first(6).map { |c| "- #{c}" }.join("\n")
        "Example comments:\n#{formatted}\n"
      else
        "Example comments: (none available)\n"
      end

    <<~PROMPT
      Generate #{num_comments} different YouTube comments for this video.

      Requirements:
      - All comments must feel distinct from each other (not just tiny wording changes).
      - Respect the preferences below for length, language and #{product_name}.
      - Each comment should be independently postable on the video.

      Video title:
      #{title}

      Video description (may be empty):
      #{description.to_s.strip.empty? ? "[no description]" : description.to_s}

      #{comments_section}
      Preferences:
      - desired_length: #{desired_length}
      - mention_product: #{mention_product}

      Return ONLY valid JSON that matches the schema, with no extra text.
    PROMPT
  end

  def json_response_format
    {
      type: :json_schema,
      json_schema: {
        name: "youtube_comments",
        strict: true,
        schema: {
          type: "object",
          properties: {
            comments: {
              type: "array",
              description: "List of generated YouTube comments.",
              items: {
                type: "object",
                properties: {
                  comment: {
                    type: "string",
                    description: "The final YouTube comment text, ready to post."
                  },
                  length: {
                    type: "string",
                    enum: %w[short medium long],
                    description: "The perceived length of the comment."
                  },
                  mentions_product: {
                    type: "boolean",
                    description: "Whether the product is explicitly mentioned."
                  }
                },
                required: %w[comment mentions_product length],
                additionalProperties: false
              }
            }
          },
          required: ["comments"],
          additionalProperties: false
        }
      }
    }
  end

  # Helper class to read project settings with defaults
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