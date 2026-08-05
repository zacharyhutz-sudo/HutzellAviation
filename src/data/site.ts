export const site = {
  name: 'Hutzell Aviation LLC',
  shortName: 'Hutzell Aviation',
  owner: 'Tyler Hutzell',
  tagline: 'Build time. Fly on your schedule.',
  location: 'Athens, Georgia',
  serviceArea: 'Aircraft rental for qualified pilots in Athens and Northeast Georgia',
  email: 'hello@hutzellaviation.com',
  phoneDisplay: '(706) 555-0148',
  phoneHref: '+17065550148',
  instagram: 'https://instagram.com/hutzellaviation',
};

export const navItems = [
  { label: 'Home', href: '' },
  { label: 'About', href: 'about/' },
  { label: 'Aircraft', href: 'aircraft/' },
  { label: 'Pricing', href: 'pricing/' },
  { label: 'Availability', href: 'availability/' },
] as const;

export const pricingPlans = [
  {
    name: 'Pay As You Go',
    hours: 'No minimum',
    rate: 'Rate coming soon',
    total: 'Pay after each flight',
    description: 'A flexible option for occasional renters who do not want to purchase a block in advance.',
    features: ['No upfront block purchase', 'Reserve approved open time', 'Final billing based on recorded aircraft time'],
    badge: '',
  },
  {
    name: '15-Hour Block',
    hours: '15 prepaid hours',
    rate: 'Discounted rate coming soon',
    total: 'Package total coming soon',
    description: 'A practical starter block for pilots planning to fly consistently over the next several months.',
    features: ['Lower hourly rate', 'Account hour balance', 'Reservation history and usage ledger'],
    badge: '',
  },
  {
    name: '25-Hour Block',
    hours: '25 prepaid hours',
    rate: 'Preferred rate coming soon',
    total: 'Package total coming soon',
    description: 'Designed for active time builders who want meaningful savings without committing to the largest package.',
    features: ['Preferred hourly rate', 'Best fit for regular flying', 'Account hour balance and receipts'],
    badge: 'Most Popular',
  },
  {
    name: '50-Hour Block',
    hours: '50 prepaid hours',
    rate: 'Best rate coming soon',
    total: 'Package total coming soon',
    description: 'The strongest value for serious time builders planning frequent and sustained aircraft use.',
    features: ['Lowest planned hourly rate', 'Built for high-frequency renters', 'Detailed package transaction ledger'],
    badge: 'Best Value',
  },
] as const;

export const aircraftSpecs = [
  { label: 'Aircraft', value: 'Piper Cherokee' },
  { label: 'Category', value: 'Single-engine land' },
  { label: 'Seating', value: 'Confirm exact configuration' },
  { label: 'Engine', value: 'Specification coming soon' },
  { label: 'Avionics', value: 'Panel details coming soon' },
  { label: 'Home Airport', value: 'Athens-area location coming soon' },
] as const;

export const rentalSteps = [
  {
    number: '01',
    title: 'Apply to rent',
    text: 'Submit your pilot background, contact information, and required documents for review.',
  },
  {
    number: '02',
    title: 'Get approved',
    text: 'Complete the renter approval process and any aircraft checkout required by Hutzell Aviation.',
  },
  {
    number: '03',
    title: 'Reserve online',
    text: 'Sign in, select an available time block, and confirm your aircraft reservation.',
  },
  {
    number: '04',
    title: 'Fly and reconcile',
    text: 'After the flight, actual aircraft time is recorded and applied to your package or invoice.',
  },
] as const;

export const rentalFaqs = [
  {
    question: 'Is Hutzell Aviation a flight school?',
    answer:
      'No. Hutzell Aviation is being developed as an aircraft-rental company for approved pilots and time builders. The company is not advertising flight instruction through the aircraft.',
  },
  {
    question: 'Who can reserve the aircraft?',
    answer:
      'Only approved renters will be able to complete a reservation. Final pilot qualifications, checkout requirements, and operating limitations will be based on the aircraft insurance policy and Hutzell Aviation rental agreement.',
  },
  {
    question: 'Can I see availability before I am approved?',
    answer:
      'Yes. The public calendar can show whether the aircraft is generally available, reserved, or unavailable without displaying another renter’s identity or trip details.',
  },
  {
    question: 'How are rental hours charged?',
    answer:
      'The final policy is still being confirmed. The booking system is designed to track the scheduled reservation window separately from actual billable aircraft time, such as Hobbs or tach time.',
  },
  {
    question: 'Can I purchase a block of hours?',
    answer:
      'Yes. The planned pricing options include pay as you go, 15-hour, 25-hour, and 50-hour packages. Final rates, expiration terms, and refund rules will be published before online purchasing is enabled.',
  },
  {
    question: 'Can an instructor rent the aircraft?',
    answer:
      'An instructor may apply as a renter. Any use of the aircraft while providing instruction to another person will require explicit approval under Hutzell Aviation’s insurance and rental policies before it is permitted.',
  },
] as const;
