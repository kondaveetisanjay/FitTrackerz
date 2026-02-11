defmodule FitconnexWeb.Auth.RegisterLive do
  use FitconnexWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Create Account", form: to_form(%{}, as: "user"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex">
      <%!-- Left: Branding Panel --%>
      <div class="hidden lg:flex lg:w-1/2 bg-gradient-to-br from-accent/15 via-base-300 to-base-200 relative overflow-hidden">
        <div class="absolute inset-0 opacity-5">
          <div class="absolute top-32 right-10 w-72 h-72 rounded-full bg-accent blur-3xl"></div>
          <div class="absolute bottom-10 left-20 w-64 h-64 rounded-full bg-primary blur-3xl"></div>
        </div>
        <div class="relative z-10 flex flex-col items-center justify-center w-full p-12">
          <div class="text-center max-w-lg">
            <div class="flex items-center justify-center gap-3 mb-6">
              <div class="w-14 h-14 rounded-xl bg-primary flex items-center justify-center">
                <.icon name="hero-bolt-solid" class="size-8 text-primary-content" />
              </div>
            </div>
            <h1 class="text-5xl font-black tracking-tight">Join FitConnex</h1>
            <p class="mt-4 text-lg text-base-content/60 leading-relaxed">
              Whether you're a gym owner, trainer, or fitness enthusiast — there's a place for you here.
            </p>
            <div class="mt-10 space-y-4 text-left max-w-sm mx-auto">
              <div class="flex items-start gap-3">
                <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center shrink-0 mt-0.5">
                  <.icon name="hero-magnifying-glass-mini" class="size-4 text-primary" />
                </div>
                <div>
                  <p class="font-semibold text-sm">Discover Gyms</p>
                  <p class="text-xs text-base-content/50">Find the perfect gym near you with real reviews and pricing.</p>
                </div>
              </div>
              <div class="flex items-start gap-3">
                <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center shrink-0 mt-0.5">
                  <.icon name="hero-calendar-days-mini" class="size-4 text-primary" />
                </div>
                <div>
                  <p class="font-semibold text-sm">Book Classes</p>
                  <p class="text-xs text-base-content/50">Schedule sessions and track your fitness progress.</p>
                </div>
              </div>
              <div class="flex items-start gap-3">
                <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center shrink-0 mt-0.5">
                  <.icon name="hero-chart-bar-mini" class="size-4 text-primary" />
                </div>
                <div>
                  <p class="font-semibold text-sm">Track Progress</p>
                  <p class="text-xs text-base-content/50">Get personalized workouts and diet plans from top trainers.</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Right: Register Form --%>
      <div class="flex-1 flex items-center justify-center p-6 sm:p-12 bg-base-100">
        <div class="w-full max-w-md">
          <%!-- Mobile Logo --%>
          <div class="lg:hidden flex items-center justify-center gap-2 mb-8">
            <div class="w-10 h-10 rounded-lg bg-primary flex items-center justify-center">
              <.icon name="hero-bolt-solid" class="size-5 text-primary-content" />
            </div>
            <span class="text-2xl font-black tracking-tight">FitConnex</span>
          </div>

          <div class="text-center mb-8">
            <h2 class="text-2xl sm:text-3xl font-black tracking-tight">Create your account</h2>
            <p class="text-base-content/50 mt-2">Start your fitness journey today</p>
          </div>

          <%!-- Flash Messages --%>
          <%= if Phoenix.Flash.get(@flash, :error) do %>
            <div class="alert alert-error text-sm mb-4">
              <.icon name="hero-exclamation-circle-mini" class="size-5" />
              <span>{Phoenix.Flash.get(@flash, :error)}</span>
            </div>
          <% end %>
          <%= if Phoenix.Flash.get(@flash, :info) do %>
            <div class="alert alert-success text-sm mb-4">
              <.icon name="hero-check-circle-mini" class="size-5" />
              <span>{Phoenix.Flash.get(@flash, :info)}</span>
            </div>
          <% end %>

          <form action="/auth/user/password/register" method="post" class="space-y-4">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div>
              <label for="user_name" class="block text-sm font-semibold mb-2">Full Name</label>
              <label class="input input-bordered flex items-center gap-3 w-full">
                <.icon name="hero-user-mini" class="size-4 opacity-40" />
                <input
                  type="text"
                  name="user[name]"
                  id="user_name"
                  placeholder="John Doe"
                  required
                  class="grow"
                  autocomplete="name"
                />
              </label>
            </div>

            <div>
              <label for="user_email" class="block text-sm font-semibold mb-2">Email</label>
              <label class="input input-bordered flex items-center gap-3 w-full">
                <.icon name="hero-envelope-mini" class="size-4 opacity-40" />
                <input
                  type="email"
                  name="user[email]"
                  id="user_email"
                  placeholder="you@example.com"
                  required
                  class="grow"
                  autocomplete="email"
                />
              </label>
            </div>

            <div>
              <label for="user_password" class="block text-sm font-semibold mb-2">Password</label>
              <label class="input input-bordered flex items-center gap-3 w-full">
                <.icon name="hero-lock-closed-mini" class="size-4 opacity-40" />
                <input
                  type="password"
                  name="user[password]"
                  id="user_password"
                  placeholder="Create a strong password"
                  required
                  minlength="8"
                  class="grow"
                  autocomplete="new-password"
                />
              </label>
              <p class="text-xs text-base-content/40 mt-1.5">Must be at least 8 characters</p>
            </div>

            <div>
              <label for="user_password_confirmation" class="block text-sm font-semibold mb-2">Confirm Password</label>
              <label class="input input-bordered flex items-center gap-3 w-full">
                <.icon name="hero-lock-closed-mini" class="size-4 opacity-40" />
                <input
                  type="password"
                  name="user[password_confirmation]"
                  id="user_password_confirmation"
                  placeholder="Re-enter your password"
                  required
                  minlength="8"
                  class="grow"
                  autocomplete="new-password"
                />
              </label>
            </div>

            <button type="submit" class="btn btn-primary w-full gap-2 font-semibold text-base mt-2">
              <.icon name="hero-rocket-launch-mini" class="size-5" />
              Create Account
            </button>
          </form>

          <div class="divider text-base-content/30 my-6 text-xs">ALREADY HAVE AN ACCOUNT?</div>

          <div class="text-center">
            <a href="/sign-in" class="btn btn-outline w-full gap-2 font-semibold">
              <.icon name="hero-arrow-right-end-on-rectangle-mini" class="size-5" />
              Sign In Instead
            </a>
          </div>

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
