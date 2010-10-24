require 'set'

class ReleaseBurndown
  attr_accessor :dates, :project, :start_date, :axis_labels, :markers

  delegate :to_s, :to => :chart

  def initialize(project)
    self.project = project
    versions = Version.find(:all,:conditions => ["project_id = ?", project.id], :order => "effective_date")
    self.start_date = versions.first.created_on.to_date
    end_date = versions.last.effective_date.to_date
    self.dates = (start_date..end_date).inject([]) { |accum, date| accum << date }
    labeled_dates = Set.new [versions.first.created_on.to_date, versions.map{|version| version.effective_date.to_date}].flatten
    axis_labels = []
    markers = []
    dates.each_with_index {|d, i|
      if labeled_dates.include?(d)
         axis_labels << d.strftime("%m-%d")
         markers << "V,DDDDFF,1,#{i},1.0" unless i == 0
      else
         axis_labels << ""
      end

      if d.to_date == Date.today
        markers << "v,BBFFBB,1,#{i},1.0"
      end
    }
    self.axis_labels = [axis_labels]
    self.markers = markers
  end

  def chart(width,height)
    Gchart.line(
      :size => "#{width}x#{height}",
      :data => data,
      :axis_with_labels => 'x,y',
      :axis_labels => axis_labels,
      :custom => "chxr=1,0,#{sprint_data.max}&chm=#{markers.join('|')}",
      :line_colors => "DDDDDD,FF0000"
    )
  end

  def data
    [ideal_data, sprint_data]
  end

  def sprint_data
    user_stories = UserStory.find(:all, :conditions => ["project_id = ?", project.id])
    story_points = user_stories.map{|user_story|
      {
        :closed_date => user_story.closed_date,
        :story_points => user_story.story_points.to_i,
      }
    }
    total_points_left = story_points.sum{|item| item[:story_points]}
    story_points = story_points.delete_if{|item| item[:closed_date].nil? }.sort_by {|item| item[:closed_date] }
    @sprint_data ||= dates.map do |date|
      while story_points.first && story_points.first[:closed_date] < date
        total_points_left -= story_points.shift[:story_points]
      end
      total_points_left
    end
  end

  def ideal_data
    [sprint_data.first, 0]
  end

end
