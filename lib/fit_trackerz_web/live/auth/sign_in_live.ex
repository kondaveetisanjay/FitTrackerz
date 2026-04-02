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
      <div class="hidden lg:flex lg:w-1/2 relative overflow-hidden bg-gradient-to-br from-primary/8 via-base-200 to-secondary/5">
        <div class="absolute inset-0 pointer-events-none">
          <div class="absolute top-20 left-10 w-56 h-56 rounded-full bg-primary/6 blur-2xl animate-float"></div>
          <div class="absolute bottom-20 right-10 w-72 h-72 rounded-full bg-secondary/5 blur-2xl animate-float-delayed"></div>
          <div class="absolute top-1/2 left-1/3 w-40 h-40 rounded-full bg-accent/4 blur-2xl animate-float-slow"></div>
        </div>

        <div class="relative z-10 flex flex-col items-center justify-center w-full p-12">
          <div class="text-center max-w-lg">
            <div class="w-16 h-16 rounded-2xl bg-gradient-to-br from-primary/20 to-primary/5 flex items-center justify-center mx-auto mb-6 ring-4 ring-primary/5">
              <.icon name="hero-bolt-solid" class="size-8 text-primary" />
            </div>
            <.brand_logo class="h-20 w-auto mx-auto" />
            <p class="mt-5 text-base text-base-content/50 leading-relaxed max-w-md mx-auto">
              Your all-in-one fitness platform. Discover gyms, book classes, and transform your fitness journey.
            </p>

            <div class="mt-10 grid grid-cols-3 gap-4">
              <div class="ft-card p-4 text-center">
                <div class="text-2xl font-black text-primary">500+</div>
                <div class="text-[10px] text-base-content/35 mt-1 font-semibold uppercase tracking-wider">Gyms Listed</div>
              </div>
              <div class="ft-card p-4 text-center">
                <div class="text-2xl font-black text-primary">1K+</div>
                <div class="text-[10px] text-base-content/35 mt-1 font-semibold uppercase tracking-wider">Classes</div>
              </div>
              <div class="ft-card p-4 text-center">
                <div class="text-2xl font-black text-primary">50K+</div>
                <div class="text-[10px] text-base-content/35 mt-1 font-semibold uppercase tracking-wider">Members</div>
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

          <div class="ft-card p-8 sm:p-10">
            <div class="text-center mb-8">
              <h2 class="text-2xl sm:text-3xl font-brand">Welcome back</h2>
              <p class="text-base-content/45 mt-2 text-sm">Sign in to your account to continue</p>
            </div>

            <%= if Phoenix.Flash.get(@flash, :error) do %>
              <div class="flex items-center gap-2 p-3 rounded-xl bg-error/10 border border-error/15 text-sm mb-5 animate-slide-down">
                <.icon name="hero-exclamation-circle-mini" class="size-5 text-error shrink-0" />
                <span class="text-error">{Phoenix.Flash.get(@flash, :error)}</span>
              </div>
            <% end %>
            <%= if Phoenix.Flash.get(@flash, :info) do %>
              <div class="flex items-center gap-2 p-3 rounded-xl bg-success/10 border border-success/15 text-sm mb-5 animate-slide-down">
                <.icon name="hero-check-circle-mini" class="size-5 text-success shrink-0" />
                <span class="text-success">{Phoenix.Flash.get(@flash, :info)}</span>
              </div>
            <% end %>

            <form action="/auth/user/password/sign_in" method="post" class="space-y-5">
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

              <div>
                <label for="user_email" class="block text-sm font-semibold mb-2">Email</label>
                <label class="input input-bordered flex items-center gap-3 w-full focus-within:input-primary focus-within:ring-2 focus-within:ring-primary/10 transition-all">
                  <.icon name="hero-envelope-mini" class="size-4 opacity-35" />
                  <input type="email" name="user[email]" id="user_email" placeholder="you@example.com" required class="grow" autocomplete="email" autofocus />
                </label>
              </div>

              <div>
                <label for="user_password" class="block text-sm font-semibold mb-2">Password</label>
                <label class="input input-bordered flex items-center gap-3 w-full focus-within:input-primary focus-within:ring-2 focus-within:ring-primary/10 transition-all">
                  <.icon name="hero-lock-closed-mini" class="size-4 opacity-35" />
                  <input type="password" name="user[password]" id="user_password" placeholder="Enter your password" required class="grow" autocomplete="current-password" />
                </label>
              </div>

              <button type="submit" class="btn btn-primary w-full gap-2 font-bold text-base shadow-lg shadow-primary/25 hover:shadow-primary/40 press-scale mt-2">
                <.icon name="hero-arrow-right-end-on-rectangle-mini" class="size-5" />
                Sign In
              </button>
            </form>

            <div class="divider text-base-content/25 my-7 text-[10px] font-bold tracking-widest uppercase">New here?</div>

            <a href="/register" class="btn btn-outline w-full gap-2 font-bold hover:bg-primary/5 press-scale">
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
