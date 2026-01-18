class CommentGenerator
  MODEL = "gpt-4o-mini"

  def initialize
    @client = OpenAI::Client.new(
      api_key: Rails.application.credentials.dig(:openai, :api_key)
    )
  end

  def generate_comments(
    product_name:,
    product_description:,
    title:,
    description: nil,
    comments: [],
    desired_length: "medium",
    mention_product: true,
    num_comments: 10
  )
    system_prompt = build_system_prompt(product_name: product_name, product_description: product_description)
    user_prompt = build_user_prompt(
      product_name: product_name,
      title: title,
      description: description,
      comments: comments,
      desired_length: desired_length,
      mention_product: mention_product,
      num_comments: num_comments
    )

    response = @client.chat.completions.create(
      model: MODEL,
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ],
      temperature: 0.9,
      max_tokens: 1000,
      response_format: {
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

  def build_system_prompt(product_name:, product_description:)
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

  def build_user_prompt(product_name:, title:, description:, comments:, desired_length:, mention_product:, num_comments:)
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
end
