match '/settings/show_tracker_custom_fields/:type' => 'settings#show_tracker_custom_fields', :via => [:get, :post]
match '/settings/show_list_options' => 'settings#show_list_options', :via => [:get, :post]
match '/settings/show_tracker_statuses' => 'settings#show_tracker_statuses', :via => [:get, :post]

match '/sync_client_field' => 'custom_fields#sync_client_field', :via => [:get, :post]