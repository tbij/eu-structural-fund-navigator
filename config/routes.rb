ActionController::Routing::Routes.draw do |map|

  map.resources :fund_items

  map.resources :fund_file_countries

  map.resources :fund_files

  map.resources :countries

  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller

  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  map.error 'errors/:country_name', :controller => 'application', :action => 'errors_by_country'

  map.to_excel 'to_excel/:country_id.csv', :controller => 'application', :action => 'to_csv_file'

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  map.root :controller => "application", :action => 'home'

  map.dashboard 'dashboard', :controller => "application", :action => 'dashboard'
  map.search 'search', :controller => 'application', :action => 'search'
  map.translate_and_search 'translate_and_search', :controller => 'application', :action => 'translate_and_search'

  map.eufunds_csv 'eufunds_csv', :controller => "application", :action => 'eufunds_csv'
  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing or commenting them out if you're using named routes and resources.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
