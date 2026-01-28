module CommentAuthorHelper
  def author_profile_image(comment)
    if comment.author_avatar_url.present?
      image_tag comment.author_avatar_url, avatar_image_tag_attributes
    elsif comment.google_account && comment.google_account.avatar_url.present?
      image_tag comment.google_account.avatar_url, avatar_image_tag_attributes
    else
      fallback_profile_image
    end
  end

  def author_display_name(comment)
    if comment.author_display_name.present?
      comment.author_display_name
    elsif comment.google_account
      comment.google_account.display_name
    else
      "—"
    end
  end

  private

  def fallback_profile_image
    tag.div class: "w-[36px] h-[36px] rounded-full bg-base-200 flex items-center justify-center" do
      tag.span class: "iconify lucide--user size-3.5 text-base-content/50"
    end
  end

  def avatar_image_tag_attributes
    { referrer_policy: "no-referrer", class: "w-[36px] h-[36px] rounded-full", alt: "" }
  end
end
