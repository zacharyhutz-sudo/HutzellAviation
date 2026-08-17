import Stripe from 'npm:stripe@^22'
import { withSupabase } from 'npm:@supabase/server@^1'

const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')
const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SIGNING_SECRET')
if (!stripeSecretKey) throw new Error('STRIPE_SECRET_KEY is not configured.')
if (!webhookSecret) throw new Error('STRIPE_WEBHOOK_SIGNING_SECRET is not configured.')

const stripe = new Stripe(stripeSecretKey)
const cryptoProvider = Stripe.createSubtleCryptoProvider()

export default {
  fetch: withSupabase({ auth: 'none' }, async (req, ctx) => {
    if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })

    const signature = req.headers.get('Stripe-Signature')
    if (!signature) return new Response('Missing Stripe signature', { status: 400 })

    const rawBody = await req.text()
    let event: Stripe.Event

    try {
      event = await stripe.webhooks.constructEventAsync(
        rawBody,
        signature,
        webhookSecret,
        undefined,
        cryptoProvider,
      )
    } catch (error) {
      console.error('Stripe webhook signature verification failed:', error)
      return new Response('Invalid Stripe signature', { status: 400 })
    }

    if (event.type !== 'checkout.session.completed') {
      return Response.json({ received: true, ignored: true })
    }

    const session = event.data.object as Stripe.Checkout.Session
    if (session.mode !== 'payment' || session.payment_status !== 'paid') {
      return Response.json({ received: true, ignored: true })
    }

    const metadata = session.metadata || {}
    const renterId = metadata.renter_id || session.client_reference_id
    const amountCents = session.amount_total

    if (!renterId || amountCents == null) {
      console.error('Stripe checkout session is missing renter or amount metadata:', session.id)
      return new Response('Missing fulfillment metadata', { status: 400 })
    }

    try {
      if (metadata.checkout_kind === 'block_purchase') {
        const packageHours = Number(metadata.package_hours)
        const { error } = await ctx.supabaseAdmin.rpc('stripe_fulfill_block_purchase', {
          p_renter_id: renterId,
          p_package_hours: packageHours,
          p_checkout_session_id: session.id,
          p_amount_cents: amountCents,
        })
        if (error) throw error
      } else if (metadata.checkout_kind === 'account_payment') {
        const paymentId = metadata.payment_id
        if (!paymentId) return new Response('Missing payment metadata', { status: 400 })
        const { error } = await ctx.supabaseAdmin.rpc('stripe_fulfill_account_payment', {
          p_renter_id: renterId,
          p_payment_id: paymentId,
          p_checkout_session_id: session.id,
          p_amount_cents: amountCents,
        })
        if (error) throw error
      } else {
        console.error('Unknown checkout kind:', metadata.checkout_kind, session.id)
        return new Response('Unknown checkout kind', { status: 400 })
      }
    } catch (error) {
      console.error('Stripe fulfillment failed:', session.id, error)
      return new Response('Fulfillment failed', { status: 500 })
    }

    return Response.json({ received: true })
  }),
}
