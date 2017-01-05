Greasyfork::Application.routes.draw do

	get 'sso', :to => 'home#sso'

	scope "(:locale)", locale: /ar|bg|cs|da|de|el|en|es|fi|fr|fr\-CA|he|hu|id|it|ja|ko|nb|nl|pl|pt\-BR|ro|ru|sk|sv|tr|uk|vi|zh\-CN|zh\-TW/ do

		get '/users', :to => 'users#index', :as => 'users'
		get '/users/webhook-info', :to => 'users#webhook_info', :as => 'user_webhook_info'
		post 'users/webhook-info', :to => 'users#webhook_info'
		get '/users/edit_sign_in' => 'users#edit_sign_in', :as => 'user_edit_sign_in'
		delete '/users/identities' => 'users#delete_identity', :as => 'user_delete_identity'
		put '/users/identities' => 'users#update_identity', :as => 'user_update_identity'
		put '/users/remove_password' => 'users#remove_password', :as => 'user_remove_password'
		put '/users/update_password' => 'users#update_password', :as => 'user_update_password'

		get '/external_login', :as => 'external_login', to: 'home#external_login'

		# disable destroying users
		devise_for :users, :skip => :registrations, :controllers => { :sessions => "sessions" }
		devise_scope :user do
			resource :registration,
			only: [:new, :create, :edit, :update],
			path: 'users',
			path_names: { new: 'sign_up' },
			controller: :registrations,
			as: :user_registration do
				get :cancel
			end
		end
		devise_scope :user do
			# a GET path for logging out for use with the forum
			get '/users/sign_out' => 'sessions#destroy'
			get '/auth/:provider/callback', to: 'sessions#omniauth_callback', :as => 'omniauth_callback'
			# BrowserID POSTs
			post '/auth/:provider/callback', to: 'sessions#omniauth_callback'
			get '/auth/failure', to: 'sessions#omniauth_failure'
			get '/auth/failure2', to: 'sessions#omniauth_failure'
			post '/auth/name_conflict', to: 'sessions#name_conflict'
		end

		root :to => "home#index"

		get 'scripts/sync_additional_info_form', :to => 'scripts#sync_additional_info_form', :as => 'script_sync_additional_info_form'
		resources :scripts, :only => [:index, :show] do
			# Deprecated after https://github.com/JasonBarnabe/greasyfork/issues/76
			get 'code.meta.js', :to => 'scripts#meta_js', :locale => nil
			get 'code.user.js', :to => 'scripts#user_js', :locale => nil

			get 'code/:name.user.js', :to => 'scripts#user_js', :as =>  'user_js', :locale => nil
			get 'code/:name.js', :to => 'scripts#user_js', :as =>  'library_js', :locale => nil
			get 'code/:name.meta.js', :to => 'scripts#meta_js', :as =>  'meta_js', :locale => nil
			# something stupid is requesting this, let's let it have it so we don't see the errors
			match 'code/:name.meta.js', :to => 'scripts#meta_js', :locale => nil, :via => :options
			get 'code(.:format)', :to => 'scripts#show_code', :as =>  'show_code', :constraints => {:format => /.*/}
			get 'feedback(.:format)', :to => 'scripts#feedback', :as =>  'feedback'
			get 'sync(.:format)', :to => 'scripts#sync', :as =>  'sync'
			patch 'sync_update(.:format)', :to => 'scripts#sync_update', :as =>  'sync_update'
			post 'install-ping', :to => 'scripts#install_ping', :as => 'install_ping', :locale => nil
			get 'diff', :to => 'scripts#diff', :as => 'diff', :constraints => lambda{ |req| !req.params[:v1].blank? and !req.params[:v2].blank? }
			get 'delete(.:format)', :to => 'scripts#delete', :as => 'delete'
			post 'delete(.:format)', :to => 'scripts#do_delete', :as => 'do_delete'
			post 'undelete(.:format)', :to => 'scripts#do_undelete', :as => 'do_undelete'
			post 'request_permanent_deletion(.:format)', :to => 'scripts#request_permanent_deletion', :as => 'request_permanent_deletion'
			post 'unrequest_permanent_deletion(.:format)', :to => 'scripts#unrequest_permanent_deletion', :as => 'unrequest_permanent_deletion'
			post 'do_permanent_deletion(.:format)', :to => 'scripts#do_permanent_deletion', :as => 'do_permanent_deletion'
			post 'reject_permanent_deletion(.:format)', :to => 'scripts#reject_permanent_deletion', :as => 'reject_permanent_deletion'
			get 'mark(.:format)', :to => 'scripts#mark', :as => 'mark'
			post 'mark(.:format)', :to => 'scripts#do_mark', :as => 'do_mark'
			get 'stats(.:format)', :to => 'scripts#stats', :as => 'stats'
			get 'derivatives', :as => 'derivatives'
			collection do
				get 'by-site(.:format)', :action => 'by_site', :as => 'site_list'
				# :site can contain a dot, make sure site doesn't eat format or vice versa
				get 'by-site/:site(.:format)', :action => 'index', :as => 'by_site', :constraints => {:site => /.*?/, :format => /|html|atom|json|jsonp/}
				get 'reported(.:format)', :action => 'reported', :as => 'reported'
				get 'reported_not_adult(.:format)', :action => 'reported_not_adult', :as => 'reported_not_adult'
				get 'requested_permanent_deletion(.:format)', :action => 'requested_permanent_deletion', :as => 'requested_permanent_deletion'
				get 'libraries(.:format)', :action => 'libraries', :as => 'libraries'
				get 'search(.:format)', :action => 'search', :as => 'search'
				get 'minified(.:format)', :action => 'minified', :as => 'minified'
				get 'code-search(.:format)', :action => 'code_search', :as => 'code_search'
				get 'redistributable(.:format)', :action => 'redistributable', :as => 'redistributable'
			end
			resources :script_versions, :only => [:create, :new, :show, :index], :path => 'versions' do
				get 'delete(.:format)', :to => 'script_versions#delete', :as => 'delete'
				post 'delete(.:format)', :to => 'script_versions#do_delete', :as => 'do_delete'
			end
		end
		resources :script_versions, :only => [:create, :new]
		get 'script_versions/additional_info_form', :to => 'script_versions#additional_info_form', :as => 'script_version_additional_info_form'
		resources :users, :only => :show do
			post 'webhook'
			resources :script_sets, :only => [:create, :new, :edit, :update, :destroy], :path => 'sets'
			get 'ban', :to => 'users#ban', :as => 'ban'
			post 'ban', :to => 'users#do_ban', :as => 'do_ban'
		end
		post 'script_sets/add_to_set', :to => 'script_sets#add_to_set', :as => 'add_to_script_set'

		get 'import', :to => 'import#index', :as => 'import_start'
		get 'import/userscriptsorg', :to => 'import#userscriptsorg', :as => 'import_userscriptsorg'
		post 'import/verify', :to => 'import#verify', :as => 'import_verify'
		post 'import/add', :to => 'import#add', :as => 'import_add'
		get 'import/url', :to => 'import#url', :as => 'import_url'

		get 'help', :to => 'help#index', :as => 'help'
		get 'help/allowed-markup', :to => 'help#allowed_markup', :as => 'help_allowed_markup'
		get 'help/code-rules', :to => 'help#code_rules', :as => 'help_code_rules'
		get 'help/contact', :to => 'help#contact', :as => 'help_contact'
		get 'help/credits', :to => 'help#credits', :as => 'help_credits'
		get 'help/disallowed-code', :to => 'help#disallowed_code', :as => 'help_disallowed_code'
		get 'help/external-scripts', :to => 'help#external_scripts', :as => 'help_external_scripts'
		get 'help/installing-user-scripts', :to => 'help#installing_user_scripts', :as => 'help_installing_user_scripts'
		get 'help/writing-user-scripts', :to => 'help#writing_user_scripts', :as => 'help_writing_user_scripts'
		get 'help/rewriting', :to => 'help#rewriting', :as => 'help_rewriting'
		get 'help/meta-keys', :to => 'help#meta_keys', :as => 'help_meta_keys'
		get 'help/privacy', :to => 'help#privacy', :as => 'help_privacy'

		post 'preview-markup', :to => 'home#preview_markup', :as => 'preview_markup'
		get 'search', to: 'home#search'

		resources :moderator_actions, :only => [:index]

		get 'opensearch.xml', to: 'opensearch#description', as: 'opensearch_description'

		match '*path', :to => 'home#routing_error', :via => [:get, :post]
	end

	match '*path', :to => 'home#routing_error', :via => [:get, :post]
end
