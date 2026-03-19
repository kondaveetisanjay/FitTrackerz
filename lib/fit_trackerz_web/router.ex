defmodule FitTrackerzWeb.Router do
  use FitTrackerzWeb, :router
  use AshAuthentication.Phoenix.Router
  import AshAuthentication.Phoenix.LiveSession, only: [ash_authentication_live_session: 3]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FitTrackerzWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public routes
  scope "/", FitTrackerzWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/about", PageController, :about
    get "/solutions/members", PageController, :solutions_members
    get "/solutions/trainers", PageController, :solutions_trainers
    get "/solutions/operators", PageController, :solutions_operators
  end

  # Auth routes - custom sign in / register pages
  ash_authentication_live_session :auth_pages,
    otp_app: :fit_trackerz,
    on_mount: [{FitTrackerzWeb.LiveUserAuth, :live_no_user}] do
    scope "/", FitTrackerzWeb do
      pipe_through :browser

      live "/sign-in", Auth.SignInLive
      live "/register", Auth.RegisterLive
    end
  end

  scope "/", FitTrackerzWeb do
    pipe_through :browser
    reset_route([])
  end

  scope "/" do
    pipe_through :browser

    sign_out_route(FitTrackerzWeb.AuthController)
    auth_routes(FitTrackerzWeb.AuthController, FitTrackerz.Accounts.User)
    get "/role-selected", FitTrackerzWeb.AuthController, :role_selected
  end

  # Public explore routes (no auth required, user loaded if present)
  ash_authentication_live_session :public_explore,
    otp_app: :fit_trackerz,
    on_mount: [{FitTrackerzWeb.LiveUserAuth, :live_user_optional}] do
    scope "/", FitTrackerzWeb do
      pipe_through :browser

      live "/explore", Explore.GymListLive
      live "/explore/contests", Explore.ContestListLive
      live "/explore/:slug", Explore.GymDetailLive
      live "/explore/:slug/pricing", Explore.GymPricingLive
    end
  end

  # Authenticated routes — generic dashboard redirect
  ash_authentication_live_session :authenticated,
    otp_app: :fit_trackerz,
    on_mount: [{FitTrackerzWeb.LiveUserAuth, :live_user_required}] do
    scope "/", FitTrackerzWeb do
      pipe_through :browser

      live "/dashboard", DashboardLive.Index
      live "/choose-role", ChooseRoleLive
    end
  end

  # Admin routes
  ash_authentication_live_session :admin,
    otp_app: :fit_trackerz,
    on_mount: [
      {FitTrackerzWeb.LiveUserAuth, :live_user_required},
      {FitTrackerzWeb.LiveUserAuth, :live_admin_required}
    ] do
    scope "/admin", FitTrackerzWeb.Admin do
      pipe_through :browser

      live "/dashboard", DashboardLive
      live "/users", UsersLive
      live "/gyms", GymsLive
    end
  end

  # Gym operator routes
  ash_authentication_live_session :gym_operator,
    otp_app: :fit_trackerz,
    on_mount: [
      {FitTrackerzWeb.LiveUserAuth, :live_user_required},
      {FitTrackerzWeb.LiveUserAuth, :live_gym_operator_required}
    ] do
    scope "/gym", FitTrackerzWeb.GymOperator do
      pipe_through :browser

      live "/dashboard", DashboardLive
      live "/setup", SetupLive
      live "/members", MembersLive
      live "/trainers", TrainersLive
      live "/classes", ClassesLive
      live "/plans", PlansLive
      live "/invitations", InvitationsLive
      live "/attendance", AttendanceLive
      live "/contests", ContestsLive
    end
  end

  # Trainer routes
  ash_authentication_live_session :trainer,
    otp_app: :fit_trackerz,
    on_mount: [
      {FitTrackerzWeb.LiveUserAuth, :live_user_required},
      {FitTrackerzWeb.LiveUserAuth, :live_trainer_required}
    ] do
    scope "/trainer", FitTrackerzWeb.Trainer do
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
    otp_app: :fit_trackerz,
    on_mount: [
      {FitTrackerzWeb.LiveUserAuth, :live_user_required},
      {FitTrackerzWeb.LiveUserAuth, :live_member_required}
    ] do
    scope "/member", FitTrackerzWeb.Member do
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
  if Application.compile_env(:fit_trackerz, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FitTrackerzWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
