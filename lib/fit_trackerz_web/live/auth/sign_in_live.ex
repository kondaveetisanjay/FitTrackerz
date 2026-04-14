defmodule FitTrackerzWeb.Auth.SignInLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Sign In", form: to_form(%{}, as: "user"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex">
      <%!-- Left: Branding Panel --%>
      <div class="hidden lg:flex lg:w-1/2 bg-gradient-to-br from-primary/20 via-base-300 to-base-200 relative overflow-hidden">
        <div class="absolute inset-0 opacity-5">
          <div class="absolute top-20 left-10 w-64 h-64 rounded-full bg-primary blur-3xl"></div>
          <div class="absolute bottom-20 right-10 w-80 h-80 rounded-full bg-secondary blur-3xl"></div>
        </div>
        <div class="relative z-10 flex flex-col items-center justify-center w-full p-12">
          <div class="text-center max-w-lg">
            <div class="w-14 h-14 rounded-xl bg-primary flex items-center justify-center mx-auto mb-6">
              <.icon name="hero-bolt-solid" class="size-8 text-primary-content" />
            </div>
            <.brand_logo class="h-20 w-auto mx-auto" />
            <p class="mt-4 text-lg text-base-content/60 leading-relaxed">
              Your all-in-one fitness platform. Discover gyms, book classes, and transform your fitness journey.
            </p>
            <div class="mt-10 grid grid-cols-3 gap-6 text-center">
              <div>
                <div class="text-2xl font-black text-primary">500+</div>
                <div class="text-xs text-base-content/40 mt-1">Gyms Listed</div>
              </div>
              <div>
                <div class="text-2xl font-black text-primary">1K+</div>
                <div class="text-xs text-base-content/40 mt-1">Classes</div>
              </div>
              <div>
                <div class="text-2xl font-black text-primary">50K+</div>
                <div class="text-xs text-base-content/40 mt-1">Members</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Right: Sign In Form --%>
      <div class="flex-1 flex items-center justify-center p-6 sm:p-12 bg-base-100">
        <div class="w-full max-w-md">
          <div class="lg:hidden flex items-center justify-center mb-8">
            <.brand_logo class="h-14 w-auto" />
          </div>

          <div class="text-center mb-8">
            <h2 class="text-2xl sm:text-3xl font-brand">Welcome back</h2>
            <p class="text-base-content/50 mt-2">Sign in to your account to continue</p>
          </div>

          <.alert :if={Phoenix.Flash.get(@flash, :error)} variant="error">
            {Phoenix.Flash.get(@flash, :error)}
          </.alert>
          <.alert :if={Phoenix.Flash.get(@flash, :info)} variant="success">
            {Phoenix.Flash.get(@flash, :info)}
          </.alert>

          <form action="/auth/user/password/sign_in" method="post" class="space-y-5 mt-4">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <.input
              type="email"
              name="user[email]"
              id="user_email"
              label="Email"
              icon="hero-envelope-mini"
              placeholder="you@example.com"
              required
              autocomplete="email"
            />

            <.input
              type="password"
              name="user[password]"
              id="user_password"
              label="Password"
              icon="hero-lock-closed-mini"
              placeholder="Enter your password"
              required
              autocomplete="current-password"
            />

            <.button type="submit" variant="primary" class="btn btn-primary w-full gap-2 font-semibold text-base rounded-xl">
              <.icon name="hero-arrow-right-end-on-rectangle-mini" class="size-5" />
              Sign In
            </.button>
          </form>

          <div class="divider text-base-content/30 my-6 text-xs">NEW HERE?</div>

          <.button navigate="/register" variant="outline" class="btn btn-outline btn-primary w-full gap-2 font-semibold rounded-xl">
            <.icon name="hero-user-plus-mini" class="size-5" />
            Create an Account
          </.button>

          <p class="text-center mt-6 text-sm text-base-content/40">
            <a href="/" class="hover:text-primary transition-colors">
              <.icon name="hero-arrow-left-mini" class="size-3.5 inline" /> Back to home
            </a>
          </p>
        </div>
      </div>
    </div>
    """
  end
end
