# Bemi

A Ruby framework for managing code workflows. Bemi allows to describe and chain multiple steps similarly to function pipelines, have the execution reliability of a background job framework, unlock full visibility into business and infrastructure processes, distribute workload and implementation across multiple services as simply as running everything in the monolith.

Bemi stands for "beginner mindset" and is pronounced as [ˈbɛmɪ].

## Contents

* [Overview](#overview)
* [Code example](#code-example)
* [Architecture](#architecture)
* [Usage](#usage)
  * [Installation](#installation)
  * [Configuration](#configuration)
  * [Workflows](#workflows)
    * [Workflow definition](#workflow-definition)
    * [Workflow validation](#workflow-validation)
    * [Workflow concurrency](#workflow-concurrency)
    * [Workflow querying](#workflow-querying)
  * [Steps](#steps)
    * [Step validation](#step-validation)
    * [Step error handling](#step-error-handling)
    * [Step rollback](#step-rollback)
    * [Step querying](#step-querying)
    * [Step concurrency](#step-concurrency)
* [Alternatives](#alternatives)
* [License](#license)
* [Code of Conduct](#code-of-conduct)

## Overview

* Explicitly defined and orchestrated workflows instead of implicit execution sequences and spaghetti code
* Synchronous, scheduled, and background execution of workflows
* Improved reliability with transactions, queues, retries, timeouts, rate limiting, and priorities
* Implemented patterns like sagas, distributed tracing, transactional outbox, and railway-oriented programming
* Full visibility into the system, event logging for debugging, auditing, and monitoring with the web UI
* Simple distributed workflow execution across services, applications, and programming languages (soon)

## Code example

Here is an example of a multi-step workflow:

```ruby
# app/workflows/order_workflow.rb
class OrderWorkflow < Bemi::Workflow
  name :order

  def perform
    step :process_payment do
      sync true
    end

    step :send_confirmation do
      wait_for [:process_payment]
      async queue: 'default'
    end

    step :ship_package do
      wait_for [:process_payment]
      async queue: 'warehouse'
    end

    step :request_feedback do
      wait_for [:ship_package]
      async queue: 'default', delay: 7.days.to_i
    end
  end
end
```

To run an instance of this workflow:

```ruby
# Init a workflow, it will stop at the first step and wait until it is executed synchronously
workflow = Bemi.perform_workflow(:order, context: { order_id: params[:order_id], user_id: current_user.id })

# Process payment by running the first workflow step synchronously
Bemi.perform_step(:process_payment, workflow_id: workflow.id, input: { payment_token: params[:payment_token] })

# Once the payment is processed, the next steps in the workflow
# will be executed automatically through background job workers
```

Each step can be implemented in a separate class that can be called "step", "service", "use case", "interactor", "mutation"...  you name it:

```ruby
# app/steps/order/process_payment_step.rb
class Order::ProcessPaymentStep < Bemi::Step
  name :process_payment

  def perform
    payment = PaymentProcessor.pay_for!(workflow.context[:order_id], input[:payment_token])
    { payment_id: payment.id }
  end
end
```

```ruby
# app/steps/order/send_confirmation_step.rb
class Order::SendConfirmationStep < Bemi::Step
  name :send_confirmation

  def perform
    payment_output = wait_for(:process_payment).output
    mail = OrderMailer.send_confirmation(payment_output[:payment_id])
    { delivered: mail.delivered? }
  end
end
```

```ruby
# ../warehouse/app/steps/order/ship_package_step.rb
class Order::ShipPackageStep < Bemi::Step
  name :ship_package

  def perform
    # Run a separate "shipment" workflow
    shipment_workflow = Bemi.perform_workflow(:shipment, context: { order_id: workflow.context[:order_id] })
    { shipment_workflow_id: shipment_workflow.id }
  end
end
```

```ruby
# app/steps/order/request_feedback_step.rb
class Order::RequestFeedbackStep < Bemi::Step
  name :request_feedback

  def perform
    mail = OrderMailer.request_feedback(workflow.context[:user_id])
    { delivered: mail.delivered? }
  end
end
```

## Architecture

Bemi is designed to be lightweight, composable, and simple to use by default.

```
         /‾‾‾\
         \___/
       __/   \__
      /   User  \
           │
 - - - - - │ - - - - - - - - - - - - - - - -
╵          │  Start "order" workflow        ╵
╵          ∨                                ╵
╵   ______________                          ╵  [‾‾‾‾‾‾‾‾‾‾‾‾]
╵  ┆  Web Server  ┆  Run "process_payment"  ╵  [------------]
╵  ┆     with     ┆⸺⸺⸺⸺⸺⸺⸺⸺⸺> [  Database  ]
╵  ┆   Bemi gem   ┆   step synchronously    ╵  [------------]
╵   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾                          ╵  [____________]
╵                                           ╵        │
╵                                           ╵        │
╵   ______________                          ╵        │
╵  |  Background  | Run "send_confirmation" ╵        │
╵  |  Job Worker  | <⸺⸺⸺⸺⸺⸺⸺⸺⸺⸺⸺│
╵  |  [default]   |       step async        ╵        │        - - - - - - - - - - - - - - - - - - -
╵   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾                          ╵        │       ╵                     ______________  ╵
╵                                           ╵        │       ╵ Run "ship_package" |  Background  | ╵
╵                                           ╵        │⸺⸺⸺⸺⸺⸺⸺⸺⸺> |  Job Worker  | ╵
╵                                           ╵        │       ╵    step async      |  [warehouse] | ╵
╵   ______________                          ╵        │       ╵                     ‾‾‾‾‾‾‾‾‾‾‾‾‾‾  ╵
╵  |  Background  |  Run "request_feedback" ╵        │       ╵                                     ╵
╵  |  Job Worker  | <⸺⸺⸺⸺⸺⸺⸺⸺⸺⸺⸺╵       ╵                                     ╵
╵  |  [default]   |    step by schedule     ╵                ╵                                     ╵
╵   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾                          ╵                ╵                                     ╵
╵                                           ╵                ╵                                     ╵
╵              Store service                ╵                ╵          Warehouse service          ╵
 - - - - - - - - - - - - - - - - - - - - - -                  - - - - - - - - - - - - - - - - - - -
```

* Database

Bemi uses a database to store the workflow execution state. It can work by connecting to PostgreSQL, MySQL, or SQLite with ActiveRecord. Note that using the whole Ruby on Rails framework is not required.

* Workflows

Bemi orchestrates workflows by relying on a database. When connecting to a database, Bemi first scans the codebase and registers all workflows uniquely identified by `name`. Workflows describe a sequence of steps in Ruby that can be run synchronously in the same process or asynchronously and by schedule as background jobs.

* Steps

Steps are also uniquely identified by `name`. They can receive data from an input, previously executed steps if they depend on them, and the shared workflow execution context. They can be implemented and executed in any service or application as long as it is connected to the same database instance. So, there is no need to deal with message passing by implementing APIs, callbacks, message buses, data serialization, etc.

* Background jobs

Steps can be scheduled or executed asynchronously by using background jobs workers. Bemi can integrate with ActiveJob or directly with popular background job processing tools like Sidekiq and Que. One worker usually represents a process with multiple threads to enable concurrency. Workers can process one or more `queues` and execute different steps across different workflows simultaneously if they are assigned to the same workers' queues.

See the [Alternatives](#alternatives) section that describes how Bemi is different from other tools you might be familiar with.

## Usage

### Installation

Add `gem 'bemi'` to your application's Gemfile and execute:

```
$ bundle install
```

### Configuration

Configure Bemi before loading your application code:

```ruby
# config/initializers/bemi.rb

# Configure Bemi
Bemi.configure do |config|
  config.storage_adapter = :active_record
  config.storage_parent_class = 'ActiveRecord::Base' # or ApplicationRecord, MyCustomConnectionRecord, etc.
  config.background_job_adapter = :active_job
  config.background_job_parent_class = 'ActiveJob::Base' # or ApplicationJob, MyCustomJob, etc.
end

# Specify a list of file paths to workflows
Bemi::Registrator.sync_workflows!(Dir.glob('app/workflows/**/*.rb'))
```

Prepare your database by creating a database migration with `bundle exec rails g migration create_bemi_tables`:

```ruby
# db/migrate/20230518121110_create_bemi_tables.rb
CreateBemiTables = Class.new(Bemi.generate_migration)
```

After running `bundle exec rails db:migrate`, you can start defining new workflows.

### Workflows

#### Workflow definition

Workflows declaratively describe steps that can be executed

* Asynchronously

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration

  def perform
    step :create_user do
      async queue: 'default'
    end

    step :send_welcome_email do
      wait_for [:create_user]
      async queue: 'default'
    end

    step :run_background_check do
      wait_for [:send_welcome_email]
      async queue: 'kyc'
    end
  end
end

Bemi.perform_workflow(:registration, context: { email: params[:email] })
```

* By schedule

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration

  def perform
    step :create_user do
      async queue: 'default', cron: '0 2 * * *' # daily at 2am
    end

    step :send_welcome_email do
      async queue: 'emails', cron: '0 3 * * *', priority: 10
    end

    step :run_background_check do
      async queue: 'default', delay: 24.hours.to_i
    end
  end
end

Bemi.perform_workflow(:registration, context: { email: params[:email] })
```

* Synchronously

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration

  def perform
    step :create_user do
      sync true
      description 'Create user'
    end

    step :send_confirmation_email do
      sync true
      description 'Send confirmation email'
    end

    step :confirm_email_address do
      sync true
      description 'Confirm email address'
    end
  end
end

workflow = Bemi.perform_workflow(:registration, context: { email: params[:email] })
Bemi.perform_step(:create_user, workflow_id: workflow.id, input: { password: params[:password] })
Bemi.perform_step(:send_confirmation_email, workflow_id: workflow.id)
Bemi.perform_step(:confirm_email_address, workflow_id: workflow.id, input: { token: params[:token] })
```

#### Workflow validation

Workflow can define the shape of the `context` to automatically validate it by using JSON Schema

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration

  context :object do
    field :email, :string, required: true
    field :premium_plan, :boolean
  end
end
```

#### Workflow concurrency

It is possible to set workflow concurrency options if you want to guarantee uniqueness

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration
  concurrency limit: 1, on_conflict: :raise # or :reject
end

Bemi.perform_workflow(:registration, context: { email: 'email@example.com' })
Bemi.perform_workflow(:registration, context: { email: 'email@example.com' })
# => Bemi::Runner::ConcurrencyError: Cannot run more than 1 'sync_registration' workflow at a time
```

#### Workflow querying

You can query workflows if, for example, one of the steps in the middle of the workflow execution needs to be triggered manually

```ruby
workflow = Bemi.find_workflow(:registration, context: { email: 'email@example.com' })

workflow.canceled?
workflow.completed?
workflow.failed?
workflow.running?

# Persisted and deserialized from JSON
workflow.context
```

### Steps

#### Step validation

Bemi allows to define and validate the shape of steps' inputs/output and context/custom_errors:

```ruby

class RegistrationWorkflow < Bemi::Workflow
  name :registration

  def perform
    step :create_user do
      sync true

      input :object do
        field :email, :string, required: true
        field :password, :string, required: true
      end

      output :object do
        field :user_id, :integer, required: true
      end
    end
  end
end

class Registration::CreateUserStep < Bemi::Step
  name :create_user

  context array: :object do
    field :onboarding_step, :string
    field :completed, :boolean
  end

  custom_errors :object do
    field :attribute, :string
    field :error, :string
  end
end
```

#### Step error handling

Custom `retry` count

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration

  def perform
    step :create_user do
      async queue: 'default'
    end

    step :send_welcome_email do
      async queue: 'default'
      on_error retry: 1
    end
  end
end
```

Custom error handler with `around_perform`

```ruby
class Registration::SendWelcomeEmailStep < Bemi::Step
  name :send_welcome_email
  around_perform :error_handler

  def perform
    user = User.find(workflow.context[:user_id])
    context[:email] = user.email
    mail = UserMailer.welcome(user.id)
    { delivered: mail.delivered? }
  end

  private

  def error_handler(&block)
    block.call
  rescue User::InvalidEmail => e
    custom_errors[:email] = "Invalid email: #{context[:email]}"
    fail! # don't retry if there is an application-level error
  rescue Errno::ECONNRESET => e
    raise e # retry by raising an exception if there is a temporary system-level error
  end
end
```

#### Step rollback

If one of the steps in a workflow fails, all previously executed steps can be rolled back by defining a method called `rollback`

```ruby
class Order::ProcessPaymentStep < Bemi::Step
  name :process_payment
  around_rollback :rollback_notifier

  def rollback
    refund = PaymentProcessor.issue_refund!(output[:payment_id], input[:payment_token])
    { refund_id: refund.id }
  end

  private

  def rollback_notifier(&block)
    OrderMailer.notify_cancelation(output[:payment_id])
    block.call
  end
end
```

#### Step querying

```ruby
workflow = Bemi.find_workflow(:registration, context: { email: 'email@example.com' })
step = Bemi.find_step(:create_user, workflow_id: workflow.id)

step.canceled?
step.completed?
step.failed?
step.running?

# Persisted and deserialized from JSON
step.input
step.output
step.custom_errors
step.context
```

#### Step concurrency

Custom concurrency `limit`

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration

  def perform
    step :create_user do
      async queue: 'default'
      concurrency limit: 1, on_conflict: :reschedule
    end
  end
end
```

Custom uniqueness key defined in `concurrency_key`

```ruby
class Registration::SendWelcomeEmailStep < Bemi::Step
  name :send_welcome_email

  def perform
    mail = UserMailer.welcome(workflow.context[:user_id])
    { delivered: mail.delivered? }
  end

  def concurrency_key
    "#{options[:async][:queue]}-#{input[:user_id]}"
  end
end
```

## Alternatives

#### Background jobs with persistent state

Tools like Sidekiq, Que, and GoodJob are similar since they execute jobs in background, persist the execution state, retry, etc. These tools, however, focus on executing a single job as a unit of work. Bemi can use these tools to perform single steps when managing chains of steps defined in workflows without a need to use complex callbacks.

Bemi orchestrates workflows instead of trying to choreograph them. This makes it easy to implement and maintain the code, reduce coordination overhead by having a central coordinator, improve observability, and simplify troubleshooting issues.

<details>
<summary>Orchestration</summary>

![Orchestration](images/orchestration.jpg)
</details>

<details>
<summary>Choreography</summary>

![Choreography](images/choreography.jpg)
</details>

#### Workflow orchestration tools and services

Tools like Temporal, AWS Step Functions, Argo Workflows, and Airflow allow orchestrating workflows, although they use quite different approaches.

Temporal was born based on challenges faced by big-tech and enterprise companies. As a result, it has a complex architecture with deployed clusters, support for databases like Cassandra and optional Elasticsearch, and multiple services for frontend, matching, history, etc. Its main differentiator is writing workflows imperatively instead of describing them declaratively (think of state machines). This makes code a lot more complex and forces you to mix business logic with implementation and execution details. Some would argue that Temporal's development and user experience are quite rough. Plus, at the time of this writing, it doesn't have an official stable SDK for our favorite programming language (Ruby).

AWS Step Functions rely on using AWS Lambda to execute each step in a workflow. For various reasons, not everyone can use AWS and their serverless solution. Additionally, workflows should be defined in JSON by using Amazon States Language instead of using a regular programming language.

Argo Workflows rely on using Kubernetes. It is closer to infrastructure-level workflows since it relies on running a container for each workflow step and doesn't provide code-level features and primitives. Additionally, it requires defining workflows in YAML.

Airflow is a popular tool for data engineering pipelines. Unfortunately, it can work only with Python.

#### Ruby frameworks for writing better code

There are many libraries that also implement useful patterns and allow better organize the code. For example, Interactor, ActiveInteraction, Mutations, Dry-Rb, and Trailblazer. They, however, don't help with asynchronous and distributed execution with better reliability guarantees that many of us rely on to execute code "out-of-band" to avoid running long-running workflows in a request/response lifecycle. For example, when sending emails, sending requests to other services, running multiple steps in parallel, etc.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Bemi project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/exAspArk/bemi/blob/master/CODE_OF_CONDUCT.md).
