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
      <div class="hidden lg:flex lg:w-1/2 relative overflow-hidden">
        <%!-- Animated gradient background --%>
        <div class="absolute inset-0 bg-gradient-to-br from-primary/10 via-base-200 to-secondary/5 animate-gradient-shift" style="background-size: 300% 300%;"></div>

        <%!-- Floating orbs --%>
        <div class="absolute inset-0">
          <div class="absolute top-20 left-10 w-72 h-72 rounded-full bg-primary/8 blur-3xl animate-float"></div>
          <div class="absolute bottom-20 right-10 w-96 h-96 rounded-full bg-secondary/6 blur-3xl animate-float-delayed"></div>
          <div class="absolute top-1/2 left-1/3 w-48 h-48 rounded-full bg-accent/5 blur-3xl animate-float-slow"></div>
        </div>

        <%!-- Decorative shapes --%>
        <div class="absolute top-12 right-12 w-20 h-20 border-2 border-primary/10 rounded-2xl rotate-12 animate-float-slow"></div>
        <div class="absolute bottom-16 left-16 w-14 h-14 border-2 border-secondary/10 rounded-full animate-float-delayed"></div>

        <div class="relative z-10 flex flex-col items-center justify-center w-full p-12">
          <div class="text-center max-w-lg">
            <div class="flex items-center justify-center gap-3 mb-6">
              <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-primary/20 to-primary/5 flex items-center justify-center backdrop-blur-xl border border-primary/10">
                <.icon name="hero-bolt-solid" class="size-8 text-primary" />
              </div>
            </div>
            <.brand_logo class="h-20 w-auto mx-auto" />
            <p class="mt-5 text-base text-base-content/50 leading-relaxed">
              Your all-in-one fitness platform. Discover gyms, book classes, and transform your fitness journey.
            </p>

            <%!-- Stats --%>
            <div class="mt-10 grid grid-cols-3 gap-6 text-center">
              <div class="p-3 rounded-xl bg-base-100/40 backdrop-blur-sm border border-base-300/20">
                <div class="text-2xl font-black text-primary">500+</div>
                <div class="text-[10px] text-base-content/35 mt-1 font-medium uppercase tracking-wider">Gyms Listed</div>
              </div>
              <div class="p-3 rounded-xl bg-base-100/40 backdrop-blur-sm border border-base-300/20">
                <div class="text-2xl font-black text-primary">1K+</div>
                <div class="text-[10px] text-base-content/35 mt-1 font-medium uppercase tracking-wider">Classes</div>
              </div>
              <div class="p-3 rounded-xl bg-base-100/40 backdrop-blur-sm border border-base-300/20">
                <div class="text-2xl font-black text-primary">50K+</div>
                <div class="text-[10px] text-base-content/35 mt-1 font-medium uppercase tracking-wider">Members</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Right: Sign In Form --%>
      <div class="flex-1 flex items-center justify-center p-6 sm:p-12 bg-base-100">
        <div class="w-full max-w-md">
          <%!-- Mobile Logo --%>
          <div class="lg:hidden flex items-center justify-center mb-8">
            <.brand_logo class="h-14 w-auto" />
          </div>

          <div class="text-center mb-8">
            <h2 class="text-2xl sm:text-3xl font-brand">Welcome back</h2>
            <p class="text-base-content/45 mt-2 text-sm">Sign in to your account to continue</p>
          </div>

          <%!-- Flash Messages --%>
          <%= if Phoenix.Flash.get(@flash, :error) do %>
            <div class="flex items-center gap-2 p-3 rounded-xl bg-error/10 border border-error/15 text-sm mb-5">
              <.icon name="hero-exclamation-circle-mini" class="size-5 text-error shrink-0" />
              <span class="text-error">{Phoenix.Flash.get(@flash, :error)}</span>
            </div>
          <% end %>
          <%= if Phoenix.Flash.get(@flash, :info) do %>
            <div class="flex items-center gap-2 p-3 rounded-xl bg-success/10 border border-success/15 text-sm mb-5">
              <.icon name="hero-check-circle-mini" class="size-5 text-success shrink-0" />
              <span class="text-success">{Phoenix.Flash.get(@flash, :info)}</span>
            </div>
          <% end %>

          <form action="/auth/user/password/sign_in" method="post" class="space-y-5">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div>
              <label for="user_email" class="block text-sm font-semibold mb-2">Email</label>
              <label class="input input-bordered flex items-center gap-3 w-full focus-within:border-primary/50 focus-within:ring-2 focus-within:ring-primary/10 transition-all">
                <.icon name="hero-envelope-mini" class="size-4 opacity-35" />
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
              <label class="input input-bordered flex items-center gap-3 w-full focus-within:border-primary/50 focus-within:ring-2 focus-within:ring-primary/10 transition-all">
                <.icon name="hero-lock-closed-mini" class="size-4 opacity-35" />
                <input
                  type="password"
                  name="user[password]"
                  id="user_password"
                  placeholder="Enter your password"
                  required
                  class="grow"
                  autocomplete="current-password"
                />
              </label>
            </div>

            <button type="submit" class="btn btn-primary w-full gap-2 font-bold text-base shadow-lg shadow-primary/25 hover:shadow-primary/40 transition-shadow">
              <.icon name="hero-arrow-right-end-on-rectangle-mini" class="size-5" />
              Sign In
            </button>
          </form>

          <div class="divider text-base-content/25 my-7 text-[10px] font-bold tracking-widest uppercase">New here?</div>

          <div class="text-center">
            <a href="/register" class="btn btn-outline w-full gap-2 font-bold hover:bg-primary/5">
              <.icon name="hero-user-plus-mini" class="size-5" />
              Create an Account
            </a>
          </div>

          <p class="text-center mt-7 text-sm text-base-content/35">
            <a href="/" class="hover:text-primary transition-colors font-medium">
              <.icon name="hero-arrow-left-mini" class="size-3.5 inline" /> Back to home
            </a>
          </p>
        </div>
      </div>
    </div>
    """
  end
end

