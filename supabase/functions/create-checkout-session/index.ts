import Stripe from 'npm:stripe@^22'
import { withSupabase } from 'npm:@supabase/server@^1'

const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')
if (!stripeSecretKey) throw new Error('STRIPE_SECRET_KEY is not configured.')

const stripe = new Stripe(stripeSecretKey)

const siteUrl = (Deno.env.get('SITE_URL') || 'https://zacharyhutz-sudo.github.io/HutzellAviation/').replace(/\/?$/, '/')

const packages = {
  15: { priceId: 'price_1U3L2d17udspvQmKM3x5lvjU', amountCents: 255000, label: '15-Hour Block' },
  25: { priceId: 'price_1U3L5217udspvQmKO6d2MsqT', amountCents: 412500, label: '25-Hour Block' },
  50: { priceId: 'price_1U3L5u17udspvQmKj8isyIuF', amountCents: 750000, label: '50-Hour Block' },
} as const

type PackageHours = keyof typeof packages

type CheckoutRequest =
  | { kind: 'block_purchase'; packageHours: number }
  | { kind: 'account_payment'; paymentId: string }

function cleanCheckoutName(value: string) {
  return value.replace(/\s+/g, ' ').trim().slice(0, 120) || 'Hutzell Aviation account payment'
}

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') {
      return Response.json({ error: 'Method not allowed.' }, { status: 405 })
    }

    const claims = ctx.userClaims as { id?: string; sub?: string; email?: string } | undefined
    const userId = claims?.id || claims?.sub
    if (!userId) return Response.json({ error: 'Unable to identify signed-in user.' }, { status: 401 })

    const { data: profile, error: profileError } = await ctx.supabase
      .from('profiles')
      .select('id,email,role,approval_status')
      .eq('id', userId)
      .single()

    if (profileError || !profile) {
      return Response.json({ error: 'Unable to load renter profile.' }, { status: 403 })
    }

    const canPay = profile.role === 'admin' || profile.approval_status === 'approved'
    if (!canPay) {
      return Response.json({ error: 'Only approved renter accounts can make online payments.' }, { status: 403 })
    }

    let body: CheckoutRequest
    try {
      body = await req.json()
    } catch {
      return Response.json({ error: 'Invalid request body.' }, { status: 400 })
    }

    const common: Stripe.Checkout.SessionCreateParams = {
      mode: 'payment',
      payment_method_types: ['card'],
      client_reference_id: userId,
      customer_email: profile.email || claims?.email,
      success_url: `${siteUrl}account/?stripe=success&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${siteUrl}account/?stripe=cancelled`,
    }

    if (body.kind === 'block_purchase') {
      const packageHours = Number(body.packageHours) as PackageHours
      const selected = packages[packageHours]
      if (!selected) return Response.json({ error: 'Invalid block-hour package.' }, { status: 400 })

      const session = await stripe.checkout.sessions.create({
        ...common,
        line_items: [{ price: selected.priceId, quantity: 1 }],
        metadata: {
          checkout_kind: 'block_purchase',
          renter_id: userId,
          package_hours: String(packageHours),
          expected_amount_cents: String(selected.amountCents),
        },
      })

      return Response.json({ url: session.url })
    }

    if (body.kind === 'account_payment') {
      const paymentId = String(body.paymentId || '').trim()
      if (!/^[0-9a-f-]{36}$/i.test(paymentId)) {
        return Response.json({ error: 'Invalid payment ID.' }, { status: 400 })
      }

      const { data: payment, error: paymentError } = await ctx.supabase
        .from('payments')
        .select('id,renter_id,status,amount_cents,kind,description')
        .eq('id', paymentId)
        .eq('renter_id', userId)
        .single()

      if (paymentError || !payment) return Response.json({ error: 'Outstanding charge not found.' }, { status: 404 })
      if (payment.status !== 'pending') return Response.json({ error: 'This charge is no longer pending.' }, { status: 409 })
      if (!Number.isInteger(payment.amount_cents) || payment.amount_cents <= 0) {
        return Response.json({ error: 'Invalid charge amount.' }, { status: 400 })
      }

      const session = await stripe.checkout.sessions.create({
        ...common,
        line_items: [{
          price_data: {
            currency: 'usd',
            unit_amount: payment.amount_cents,
            product_data: { name: cleanCheckoutName(payment.description || 'Hutzell Aviation account payment') },
          },
          quantity: 1,
        }],
        metadata: {
          checkout_kind: 'account_payment',
          renter_id: userId,
          payment_id: payment.id,
          expected_amount_cents: String(payment.amount_cents),
        },
      }, {
        idempotencyKey: `hutzell-payment-${payment.id}`,
      })

      return Response.json({ url: session.url })
    }

    return Response.json({ error: 'Unsupported checkout type.' }, { status: 400 })
  }),
}
