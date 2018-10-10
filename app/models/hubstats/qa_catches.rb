module Hubstats
    class QaCatches < ActiveRecord::Base
  
      def self.record_timestamps; false; end
  
      # Various checks that can be used to filter and find info about QA Catches.
      scope :signed_within_date_range, lambda {|start_date, end_date| where("hubstats_qa_signoffs.signed_at BETWEEN ? AND ?", start_date, end_date)}
      scope :belonging_to_repo, lambda {|repo_id| where(repo_id: repo_id)}
      scope :belonging_to_user, lambda {|user_id| where(user_id: user_id)}
      scope :belonging_to_team, lambda {|user_ids| where(user_id: user_ids) if user_ids}
      scope :created_in_date_range, lambda {|start_date, end_date| where("hubstats_comments.created_at BETWEEN ? AND ?", start_date, end_date)}
      scope :ignore_comments_by, lambda {|user_ids| where.not(user_id: user_ids || []) if user_ids}
      scope :belonging_to_pull_request, lambda {|pull_request_id| where(pull_request_id: pull_request_id)}
      
      
      
  
      # Public - Gets the number of PRs that a user QA Catches on that were not their own PR.
      #
      # Returns - the number of PRs that a specific user has tested
      scope :pull_qa_catches_count, lambda {
        select("hubstats_comments.user_id")
        .select("COUNT(DISTINCT hubstats_pull_requests.id) as total")
        .joins("LEFT JOIN hubstats_pull_requests ON hubstats_pull_requests.id = hubstats_comments.pull_request_id")
        .where("hubstats_pull_requests.user_id != hubstats_comments.user_id")
        .group("hubstats_comments.user_id")
      }
    
      belongs_to :user
      belongs_to :pull_request
      belongs_to :repo
     
      # Public - Makes a new comment based on a GitHub webhook occurrence. Assigns the user and the PR.
      #
      # github_comment - the information from Github about the comment
      def self.create_or_update(github_comment)
        github_comment = github_comment.to_h.with_indifferent_access if github_comment.respond_to? :to_h
  
        unless github_comment[:user]
          Rails.logger.warn "Found comment with no user, ignoring. GitHub comment ID: #{github_comment[:id]}"
          return nil
        end
  
        user = Hubstats::User.create_or_update(github_comment[:user])
        github_comment[:user_id] = user.id
        
        if github_comment[:pull_number]
          pull_request = Hubstats::PullRequest.belonging_to_repo(github_comment[:repo_id]).where(number: github_comment[:pull_number]).first
          if pull_request
            github_comment[:pull_request_id] = pull_request.id
          end
        end
  
        comment_data = github_comment.slice(*Hubstats::Comment.column_names.map(&:to_sym))
  
        comment = where(:id => comment_data[:id]).first_or_create(comment_data)
        return comment if comment.update_attributes(comment_data)
        Rails.logger.warn comment.errors.inspect
      end
  
    end
  end
  