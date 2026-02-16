defmodule FitconnexWeb.Router do
  use FitconnexWeb, :router
  use AshAuthentication.Phoenix.Router
  import AshAuthentication.Phoenix.LiveSession, only: [ash_authentication_live_session: 3]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FitconnexWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public routes
  scope "/", FitconnexWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/about", PageController, :about
    get "/solutions/members", PageController, :solutions_members
    get "/solutions/trainers", PageController, :solutions_trainers
    get "/solutions/operators", PageController, :solutions_operators
  end

  # Auth routes - custom sign in / register pages
  ash_authentication_live_session :auth_pages,
    otp_app: :fitconnex,
    on_mount: [{FitconnexWeb.LiveUserAuth, :live_no_user}] do
    scope "/", FitconnexWeb do
      pipe_through :browser

      live "/sign-in", Auth.SignInLive
      live "/register", Auth.RegisterLive
    end
  end

  scope "/", FitconnexWeb do
    pipe_through :browser
    reset_route([])
  end

  scope "/" do
    pipe_through :browser

    sign_out_route(FitconnexWeb.AuthController)
    auth_routes(FitconnexWeb.AuthController, Fitconnex.Accounts.User)
    get "/role-selected", FitconnexWeb.AuthController, :role_selected
  end

  # Public explore routes (no auth required, user loaded if present)
  ash_authentication_live_session :public_explore,
    otp_app: :fitconnex,
    on_mount: [{FitconnexWeb.LiveUserAuth, :live_user_optional}] do
    scope "/", FitconnexWeb do
      pipe_through :browser

      live "/explore", Explore.GymListLive
      live "/explore/:slug", Explore.GymDetailLive
    end
  end

  # Authenticated routes — generic dashboard redirect
  ash_authentication_live_session :authenticated,
    otp_app: :fitconnex,
    on_mount: [{FitconnexWeb.LiveUserAuth, :live_user_required}] do
    scope "/", FitconnexWeb do
      pipe_through :browser

      live "/dashboard", DashboardLive.Index
      live "/choose-role", ChooseRoleLive
    end
  end

  # Admin routes
  ash_authentication_live_session :admin,
    otp_app: :fitconnex,
    on_mount: [
      {FitconnexWeb.LiveUserAuth, :live_user_required},
      {FitconnexWeb.LiveUserAuth, :live_admin_required}
    ] do
    scope "/admin", FitconnexWeb.Admin do
      pipe_through :browser

      live "/dashboard", DashboardLive
      live "/users", UsersLive
      live "/gyms", GymsLive
    end
  end

  # Gym operator routes
  ash_authentication_live_session :gym_operator,
    otp_app: :fitconnex,
    on_mount: [
      {FitconnexWeb.LiveUserAuth, :live_user_required},
      {FitconnexWeb.LiveUserAuth, :live_gym_operator_required}
    ] do
    scope "/gym", FitconnexWeb.GymOperator do
      pipe_through :browser

      live "/dashboard", DashboardLive
      live "/setup", SetupLive
      live "/members", MembersLive
      live "/trainers", TrainersLive
      live "/classes", ClassesLive
      live "/plans", PlansLive
      live "/invitations", InvitationsLive
      live "/attendance", AttendanceLive
    end
  end

  # Trainer routes
  ash_authentication_live_session :trainer,
    otp_app: :fitconnex,
    on_mount: [
      {FitconnexWeb.LiveUserAuth, :live_user_required},
      {FitconnexWeb.LiveUserAuth, :live_trainer_required}
    ] do
    scope "/trainer", FitconnexWeb.Trainer do
      pipe_through :browser

      live "/dashboard", DashboardLive
      live "/gyms", GymsLive
      live "/gyms/:id", GymDetailLive
      live "/clients", ClientsLive
      live "/workouts", WorkoutsLive
      live "/diets", DietsLive
      live "/templates", TemplatesLive
      live "/classes", ClassesLive
      live "/attendance", AttendanceLive
    end
  end

  # Member routes
  ash_authentication_live_session :member,
    otp_app: :fitconnex,
    on_mount: [{FitconnexWeb.LiveUserAuth, :live_user_required}] do
    scope "/member", FitconnexWeb.Member do
      pipe_through :browser

      live "/dashboard", DashboardLive
      live "/gym", GymLive
      live "/gym/:id", GymDetailLive
      live "/trainer", TrainerLive
      live "/workout", WorkoutLive
      live "/diet", DietLive
      live "/classes", ClassesLive
      live "/bookings", BookingsLive
      live "/subscription", SubscriptionLive
      live "/attendance", AttendanceLive
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:fitconnex, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FitconnexWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
