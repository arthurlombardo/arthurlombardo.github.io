# _plugins/inherit_from_ref.rb
require 'yaml'
require 'time'

module Jekyll
  module InheritFromRefFilter
    # ------------------------------------------------------------------
    # Helper: read raw front matter from a post's source file
    # Returns a hash of explicitly set front matter keys.
    # ------------------------------------------------------------------
    def raw_front_matter(post, site)
      return {} unless post.respond_to?(:path)
      file_path = File.join(site.source, post.path)
      return {} unless File.exist?(file_path)

      content = File.read(file_path)
      if content =~ /\A(---\s*\n.*?\n?)^(---\s*$\n?)/m
        raw = YAML.safe_load($1, permitted_classes: [Time, Date])
        return raw ? raw : {}
      end
      {}
    rescue => e
      Jekyll.logger.warn "inherit_from_ref:", "Could not parse #{file_path}: #{e.message}"
      {}
    end

    # ------------------------------------------------------------------
    # Core logic: get the effective title of a post
    # - If the post has an explicit 'title' in its raw front matter → use that
    # - Else if the post has a 'paper' reference → use the referenced paper's title
    # - Else → use the post's default title (Jekyll's fallback, usually filename‑derived)
    # ------------------------------------------------------------------
    def effective_title_for(post, site)
      raw = raw_front_matter(post, site)

      # Check for explicit title in raw front matter
      if raw.key?('title') && raw['title'] && !raw['title'].to_s.empty?
        return raw['title']
      end

      # No explicit title: try to inherit from referenced paper
      if raw.key?('paper') && raw['paper']
        ref_slug = raw['paper'].to_s
        referenced = site.documents.find { |doc| doc.data['slug'] == ref_slug }
        referenced = site.posts.docs.find { |doc| doc.data['slug'] == ref_slug } unless referenced

        if referenced && referenced.data['title']
          return referenced.data['title']
        end
      end

      # Fallback: Jekyll's default title (the one that appears in post.title)
      post.data['title']
    end

    # ------------------------------------------------------------------
    # Liquid filter: returns the effective title as a string
    # Usage: {{ page | effective_title }}
    # ------------------------------------------------------------------
    def effective_title(input)
      site = @context.registers[:site]
      effective_title_for(input, site)
    end

    # ------------------------------------------------------------------
    # Liquid filter: returns the full merged hash (paper + talk)
    # Usage: {{ page | inherit_from_ref: "paper" }}
    # ------------------------------------------------------------------
    def inherit_from_ref(input, ref_field)
      return input unless input[ref_field]

      ref_slug = input[ref_field].to_s
      site = @context.registers[:site]
      return input unless site

      referenced = site.documents.find { |doc| doc.data['slug'] == ref_slug }
      referenced = site.posts.docs.find { |doc| doc.data['slug'] == ref_slug } unless referenced
      return input unless referenced

      # Start with referenced post's data
      merged = referenced.data.dup

      # Read raw front matter of the talk (to know which fields were explicitly set)
      raw_talk = raw_front_matter(input, site)

      # Merge all explicit talk fields, with special handling for title
      raw_talk.each do |k, v|
        if k.to_s == 'title'
          # Use talk's title only if it was explicitly given (non‑empty)
          merged['title'] = v if v && !v.to_s.empty?
        else
          merged[k] = v unless v.nil?
        end
      end

      # Date: use talk's file date if present, otherwise paper's date
      merged['date'] = input['date'] || referenced.date

      merged
    end
  end
end

Liquid::Template.register_filter(Jekyll::InheritFromRefFilter)