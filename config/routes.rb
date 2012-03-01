if defined? map
  map.resources :public_keys, :controller => 'gitolite_public_keys', :path_prefix => 'my'
  map.connect  'gitolite_hook', :controller => 'gitolite_hook', :action => 'index'
else
  ActionController::Routing::Routes.draw do |map|
    map.resources :public_keys, :controller => 'gitolite_public_keys', :path_prefix => 'my'
    map.connect  'gitolite_hook', :controller => 'gitolite_hook', :action => 'index'
  end
end
