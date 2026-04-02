defmodule FitTrackerzWeb.Auth.RegisterLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Create Account", form: to_form(%{}, as: "user"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex">
      <%!-- Left: Branding Panel --%>
      <div class="hidden lg:flex lg:w-1/2 relative overflow-hidden bg-gradient-to-br from-primary/8 via-base-200 to-accent/5">
        <div class="absolute inset-0 pointer-events-none">
          <div class="absolute top-32 right-10 w-56 h-56 rounded-full bg-accent/5 blur-2xl animate-float"></div>
          <div class="absolute bottom-10 left-20 w-48 h-48 rounded-full bg-primary/5 blur-2xl animate-float-delayed"></div>
        </div>
        <div class="relative z-10 flex flex-col items-center justify-center w-full p-12">
          <div class="text-center max-w-lg">
            <div class="w-16 h-16 rounded-2xl bg-gradient-to-br from-primary/20 to-primary/5 flex items-center justify-center mx-auto mb-6 ring-4 ring-primary/5">
              <.icon name="hero-bolt-solid" class="size-8 text-primary" />
            </div>
            <.brand_logo class="h-20 w-auto mx-auto" />
            <h1 class="text-3xl font-brand mt-4">Join Us</h1>
            <p class="mt-4 text-base text-base-content/50 leading-relaxed">
              Whether you're a gym owner or fitness enthusiast — there's a place for you here.
            </p>

            <div class="mt-10 space-y-3 text-left max-w-sm mx-auto">
              <div class="ft-card p-4 flex items-start gap-3">
                <div class="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
                  <.icon name="hero-magnifying-glass-mini" class="size-4 text-primary" />
                </div>
                <div>
                  <p class="font-semibold text-sm">Discover Gyms</p>
                  <p class="text-xs text-base-content/50 mt-0.5">Find the perfect gym near you with real reviews and pricing.</p>
                </div>
              </div>
              <div class="ft-card p-4 flex items-start gap-3">
                <div class="w-9 h-9 rounded-xl bg-info/10 flex items-center justify-center shrink-0">
                  <.icon name="hero-calendar-days-mini" class="size-4 text-info" />
                </div>
                <div>
                  <p class="font-semibold text-sm">Book Classes</p>
                  <p class="text-xs text-base-content/50 mt-0.5">Schedule sessions and track your fitness progress.</p>
                </div>
              </div>
              <div class="ft-card p-4 flex items-start gap-3">
                <div class="w-9 h-9 rounded-xl bg-accent/10 flex items-center justify-center shrink-0">
                  <.icon name="hero-chart-bar-mini" class="size-4 text-accent" />
                </div>
                <div>
                  <p class="font-semibold text-sm">Track Progress</p>
                  <p class="text-xs text-base-content/50 mt-0.5">Get personalized workouts and diet plans to achieve your goals.</p>
                </div>
              </div>
            </div>

            <div class="mt-8 space-y-2.5">
              <div class="flex items-center gap-2 text-base-content/60 justify-center">
                <.icon name="hero-check-circle-solid" class="size-5 text-success" />
                <span class="text-sm">Free to register</span>
              </div>
              <div class="flex items-center gap-2 text-base-content/60 justify-center">
                <.icon name="hero-check-circle-solid" class="size-5 text-success" />
                <span class="text-sm">No credit card required</span>
              </div>
              <div class="flex items-center gap-2 text-base-content/60 justify-center">
                <.icon name="hero-check-circle-solid" class="size-5 text-success" />
                <span class="text-sm">Instant access</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Right: Register Form --%>
      <div class="flex-1 flex items-center justify-center p-6 sm:p-12 bg-base-100">
        <div class="w-full max-w-md">
          <div class="lg:hidden flex items-center justify-center mb-8">
            <.brand_logo class="h-14 w-auto" />
          </div>

          <div class="ft-card p-8 sm:p-10">
            <div class="text-center mb-8">
              <h2 class="text-2xl sm:text-3xl font-brand">Create your account</h2>
              <p class="text-base-content/50 mt-2 text-sm">Start your fitness journey today</p>
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

            <form action="/auth/user/password/register" method="post" class="space-y-5">
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

              <div>
                <label for="user_name" class="block text-sm font-semibold mb-2">Full Name</label>
                <label class="input input-bordered flex items-center gap-3 w-full focus-within:input-primary focus-within:ring-2 focus-within:ring-primary/10 transition-all">
                  <.icon name="hero-user-mini" class="size-4 opacity-40" />
                  <input type="text" name="user[name]" id="user_name" placeholder="John Doe" required class="grow" autocomplete="name" autofocus />
                </label>
              </div>

              <div>
                <label for="user_email" class="block text-sm font-semibold mb-2">Email</label>
                <label class="input input-bordered flex items-center gap-3 w-full focus-within:input-primary focus-within:ring-2 focus-within:ring-primary/10 transition-all">
                  <.icon name="hero-envelope-mini" class="size-4 opacity-40" />
                  <input type="email" name="user[email]" id="user_email" placeholder="you@example.com" required class="grow" autocomplete="email" />
                </label>
              </div>

              <div>
                <label for="user_password" class="block text-sm font-semibold mb-2">Password</label>
                <label class="input input-bordered flex items-center gap-3 w-full focus-within:input-primary focus-within:ring-2 focus-within:ring-primary/10 transition-all">
                  <.icon name="hero-lock-closed-mini" class="size-4 opacity-40" />
                  <input type="password" name="user[password]" id="user_password" placeholder="Create a strong password" required minlength="8" class="grow" autocomplete="new-password" />
                  <button type="button" onclick="togglePasswordVisibility('user_password', this)" class="btn btn-ghost btn-xs btn-circle">
                    <.icon name="hero-eye-mini" class="size-4 opacity-40" />
                  </button>
                </label>
                <p class="text-xs text-base-content/40 mt-1.5">Must be at least 8 characters</p>
              </div>

              <div>
                <label for="user_password_confirmation" class="block text-sm font-semibold mb-2">Confirm Password</label>
                <label class="input input-bordered flex items-center gap-3 w-full focus-within:input-primary focus-within:ring-2 focus-within:ring-primary/10 transition-all">
                  <.icon name="hero-lock-closed-mini" class="size-4 opacity-40" />
                  <input type="password" name="user[password_confirmation]" id="user_password_confirmation" placeholder="Re-enter your password" required minlength="8" class="grow" autocomplete="new-password" />
                  <button type="button" onclick="togglePasswordVisibility('user_password_confirmation', this)" class="btn btn-ghost btn-xs btn-circle">
                    <.icon name="hero-eye-mini" class="size-4 opacity-40" />
                  </button>
                </label>
              </div>

              <script>
                function togglePasswordVisibility(inputId, btn) {
                  const input = document.getElementById(inputId);
                  if (input.type === 'password') {
                    input.type = 'text';
                    btn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="size-4 opacity-40"><path fill-rule="evenodd" d="M3.28 2.22a.75.75 0 0 0-1.06 1.06l14.5 14.5a.75.75 0 1 0 1.06-1.06l-1.745-1.745a10.029 10.029 0 0 0 3.3-4.38 1.651 1.651 0 0 0 0-1.185A10.004 10.004 0 0 0 9.999 3a9.956 9.956 0 0 0-4.744 1.194L3.28 2.22ZM7.752 6.69l1.092 1.092a2.5 2.5 0 0 1 3.374 3.373l1.092 1.092a4 4 0 0 0-5.558-5.558Z" clip-rule="evenodd" /><path d="M10.748 13.93l2.523 2.523a9.987 9.987 0 0 1-3.27.547c-4.258 0-7.894-2.66-9.337-6.41a1.651 1.651 0 0 1 0-1.186A10.007 10.007 0 0 1 2.839 6.02L6.07 9.252a4 4 0 0 0 4.678 4.678Z" /></svg>';
                  } else {
                    input.type = 'password';
                    btn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="size-4 opacity-40"><path d="M10 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z" /><path fill-rule="evenodd" d="M.664 10.59a1.651 1.651 0 0 1 0-1.186A10.004 10.004 0 0 1 10 3c4.257 0 7.893 2.66 9.336 6.41.147.381.146.804 0 1.186A10.004 10.004 0 0 1 10 17c-4.257 0-7.893-2.66-9.336-6.41Z" clip-rule="evenodd" /></svg>';
                  }
                }
              </script>

              <button type="submit" class="btn btn-primary w-full gap-2 font-bold text-base shadow-lg shadow-primary/25 hover:shadow-primary/40 press-scale mt-2">
                <.icon name="hero-rocket-launch-mini" class="size-5" />
                Create Account
              </button>
            </form>

            <div class="divider text-base-content/25 my-7 text-[10px] font-bold tracking-widest uppercase">Already have an account?</div>

            <a href="/sign-in" class="btn btn-outline w-full gap-2 font-bold hover:bg-primary/5 press-scale">
              <.icon name="hero-arrow-right-end-on-rectangle-mini" class="size-5" />
              Sign In Instead
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
