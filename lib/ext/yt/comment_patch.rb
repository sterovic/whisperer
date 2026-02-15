module Yt
  module Collections
    class CommentThreads < Base
      # Insert a new comment thread (top-level comment)
      def insert(attributes = {})
        InsertableCommentThreads.new(auth: @auth).insert attributes
      end
    end

    class InsertableCommentThreads < Resources
      def self.to_s
        "CommentThreads"
      end

      private

      def insert_parts
        {
          snippet: {
            keys: [:snippet, :topLevelComment, :videoId],
            topLevelComment: {
              keys: [:snippet],
              snippet: {
                keys: [:textOriginal]
              }
            }
          }
        }
      end

      def build_insert_body(attributes)
        {
          snippet: {
            videoId: attributes[:video_id],
            topLevelComment: { snippet: { textOriginal: attributes[:text_original] } }
          }
        }
      end
    end

    class Comments < Resources
      # Insert a comment (reply to existing comment or thread)
      def insert(attributes = {})
        super({ parent_id: attributes[:parent_id], text: attributes[:text] })
      end

      private

      def list_params
        super.tap do |params|
          params[:params] = {
            parent_id: @parent.id,
            part: "snippet"
          }

          puts params
        end
      end

      def insert_parts
        {
          snippet: {
            keys: [:parentId, :textOriginal], sanitize_brackets: true
          }
        }
      end

      def build_insert_body(attributes)
        {
          snippet: {
            parentId: attributes[:parent_id],
            textOriginal: attributes[:text]
          }
        }
      end
    end
  end

  module Models
    class Account
      # Access to comment_threads collection with insert capability
      def comment_threads
        @comment_threads ||= Collections::CommentThreads.new(auth: self)
      end

      # Access to comments collection with insert capability
      def comments
        @comments ||= Collections::Comments.new(auth: self)
      end

      def access_token_was_refreshed
        puts "access token was refreshed"
      end
    end

    class Comment
      def author_profile_image_url
        snippet.data["authorProfileImageUrl"]
      end
    end

    class CommentThread
      def author_profile_image_url
        top_level_comment.snippet.data["authorProfileImageUrl"]
      end

      def replies
        @replies ||= Collections::Comments.new(auth: @auth, parent: self)
      end
    end
  end
end
