class EventsController < ApplicationController
    include EventsHelper
    before_action :authorize_user

    def new
        @event = Event.new
    end

    def create
        event = Event.new(event_params)
        event.user = current_user
        event.midpoint = Midpoint.first
        
        if event.save 
            flash[:success] = "SUCCESS >>> New Event Created Sucessfully"
        else
            flash[:error] = "ERROR >>> Event Creation Fail #{event.errors.full_messages}"
        end
        respond_to do |format|  
            format.js
        end
    end

    def meetpoint 
        @event = Event.find(params[:event_id])
        @event.update(midpoint_id: params[:id])
        respond_to do |format|  
            format.js
        end
    end

    def detail
        @event = Event.find(params[:id])
        respond_to do |format|  
            format.js
        end
    end

    def show
        @event = Event.find(params[:id])
        @colabs = @event.invites
        @users = @colabs.joins(:user)

        longtitude_tot = @users.maximum(:longtitude).to_f + @users.minimum(:longtitude).to_f
        latitude_tot = @users.maximum(:latitude).to_f + @users.minimum(:latitude).to_f
        
        zoom = 10;
   
        @center = [ longtitude_tot / 2, latitude_tot / 2 , zoom]
        @Locresults = Midpoint.all

        if @colabs.count == 0
            @center = [ 108.649, 5.509 , 6]
        end

    end


    def event_map
        bundle, user_location, target_location, midpoint_all_location = [], [], [], []
        colabs = Event.find(params[:event_id]).invites
        midpoints = Midpoint.all

        colabs.each do |i|
            u = i.user
            user_location << {
                "id": "poi.1580547980092", #get from database
                "type": "Feature",
                "relevance": 1,
                "properties": {
                    "description": "<img src='https://i.ibb.co/yPYz8x4/ruby-pin.gif' height='142' width='100'> 
                        <br> #{u.username} 
                        <br> Coordinates: #{u.longtitude}, #{u.latitude} 
                        <br> Language: <span class='user_lang'> #{u.lang} </span>
                        <br> User ID: #<span class='user_id'>#{u.id}</span>", #print to div
                    "landmark": true,
                    "category": "college, university, building",
                    "iconSize": [60, 60],
                    "lang": "#{u.lang}",
                    "username": "#{u.username}",
                    "user_mail": "#{u.email}",
                },
                "text": "Next Academy",
                "place_name": "Next Academy, Kuala Lumpur, 60000, Malaysia",
                "center": [u.longtitude, u.latitude], #
                "geometry": {
                    "coordinates": [u.longtitude, u.latitude], #
                    "type": "Point"
                }
            }
        end
        user = {"type": "FeatureCollection", "features":  user_location}
    
        #detect outlier
        #remove outlier
        #using SD as limit
        lng_arr = DescriptiveStatistics::Stats.new([])
        lat_arr = DescriptiveStatistics::Stats.new([])
        colabs.each do |i|
            lng_arr << i.user.longtitude.to_f
            lat_arr << i.user.latitude.to_f
        end
        lng_arr = lng_arr.sort
        lat_arr = lat_arr.sort

        lng_s_d = s_d(lng_arr)
        lat_s_d = s_d(lat_arr)
        
        s_d_limit = 0.2
        lng_arr_length = lng_arr.length
        colabs = colabs.joins(:user)
        
        while lng_s_d > s_d_limit
            lng_arr = eval_lower(lng_arr)
            if lng_arr.length < lng_arr_length
                colabs = colabs.where("longtitude != ?", colabs.minimum(:longtitude).to_s)
                lng_arr_length = lng_arr.length
            end
            
            lng_arr = eval_upper(lng_arr)
            if lng_arr.length < lng_arr_length
                colabs = colabs.where("longtitude != ?", colabs.maximum(:longtitude).to_s)
                lng_arr_length = lng_arr.length
            end
            lng_s_d = s_d(lng_arr)
        end

        # only search within radius
        max_lat = colabs.maximum(:latitude).to_f 
        min_lat = colabs.minimum(:latitude).to_f 
        max_lng = colabs.maximum(:longtitude).to_f
        min_lng = colabs.minimum(:longtitude).to_f
        
        # search for midpoint within
        midpoints = midpoints.where("longtitude < ? AND longtitude > ? AND latitude < ? AND latitude > ?", max_lng, min_lng, max_lat, min_lat)

        midpoints.all.each do |p|
            target_location << {
                "id": "#{p.poi}",
                "type": "Feature",
                "relevance": 1,
                "properties": {
                    "name": "<div style='max-width: 350px;'>
                    <img src='#{p.photo}' height='350' width='350' style='background-size: cover; background-position: 50% 50%; border-radius: 10px;'>
                    <br><h4 class='username-text'>#{p.name}</h4>
                    <br>#{p.description}
                    </div>", #
                    "address": "#{p.address}",
                    "pname": "#{p.name}",
                    "description": "#{p.description}", #
                    "category": "#{p.category}",
                    "landmark": true,
                    "midpoint_id": "#{p.id}",
                    "photo": "#{p.photo}",
                },
                "center": [p.longtitude, p.latitude], #
                "geometry": {
                    "coordinates": [p.longtitude, p.latitude], #
                    "type": "Point",
                }
            }
        end
        target = {"type": "FeatureCollection", "features":  target_location}


        Midpoint.all.each do |p|
            midpoint_all_location << {
                "id": "#{p.poi}",
                "type": "Feature",
                "relevance": 1,
                "properties": {
                    "name": "<div style='max-width: 350px;'>
                    <img src='#{p.photo}' height='350' width='350' style='background-size: cover; background-position: 50% 50%; border-radius: 10px;'>
                    <br><h4 class='username-text'>#{p.name}</h4>
                    <br>#{p.description}
                    </div>", #
                    "address": "#{p.address}",
                    "pname": "#{p.name}",
                    "description": "#{p.description}", #
                    "category": "#{p.category}",
                    "landmark": true,
                    "midpoint_id": "#{p.id}",
                    "photo": "#{p.photo}",
                },
                "center": [p.longtitude, p.latitude], #
                "geometry": {
                    "coordinates": [p.longtitude, p.latitude], #
                    "type": "Point",
                }
            }
        end
        midpoint_all = {"type": "FeatureCollection", "features":  midpoint_all_location}

        user_location = []
        Event.find(params[:event_id]).invites.each do |i|
            u = i.user
            user_location << {
                "id": "poi.1580547980092", #get from database
                "type": "Feature",
                "relevance": 1,
                "properties": {
                    "description": "<div class='popup-user'><img src='#{u.avatar}' height='142' width='150'> 
                    <br><span class='username'><h4 class='username-text'>#{u.username}</h4> </span>
                    <br> <h5 class='lang-text'>Ruby</h5> 
                    <br> <p class='des-text'>About me:</p> <span class='description'><p class='des-text'>#{u.description}</p></span>
                    <br> <p class='des-text'>Email me: #{u.email}</p>
                    <br> <span class='user_lang d-none'> #{u.lang} </span>
                    <br> <span class='d-none'>User ID: #<span class='user_id'>#{u.id}</span></span>", #
                    "landmark": true,
                    "category": "college, university, building",
                    "iconSize": [60, 60],
                    "lang": "#{u.lang}",
                    "username": "#{u.username}",
                    "user_mail": "#{u.email}",
                },
                "text": "Next Academy",
                "place_name": "Next Academy, Kuala Lumpur, 60000, Malaysia",
                "center": [u.longtitude, u.latitude], #
                "geometry": {
                    "coordinates": [u.longtitude, u.latitude], #
                    "type": "Point"
                }
            }
        end
        user = {"type": "FeatureCollection", "features":  user_location}
    

        bundle << user
        bundle << target
        bundle << midpoint_all
        render :json => ActiveSupport::JSON.encode(bundle)
    end

    private
    def event_params
        params.require(:event).permit(
          :user_id, 
          :midpoint_id, 
          :remark, 
          :event_date,
          :event_time,
        )
    end

    def authorize_user
        redirect_to root_path if !signed_in?
    end
end
