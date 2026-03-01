Rails.application.routes.draw do
  root 'chats#index'
  resources :chats, only: [:index, :create]
  resources :conversations, only: [:create, :destroy]
  resources :images, only: [:new, :create]
  resource :session, only: [:update]
end