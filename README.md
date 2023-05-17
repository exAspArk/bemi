# Bemi

A Ruby framework for managing code workflows. Bemi allows to describe and chain multiple actions similarly to function pipelines, have the execution reliability of a background job framework, unlock full visibility into business and infrastructure processes, distribute workload and implementation across multiple services as simply as running everything in the monolith.

Bemi stands for "beginner mindset" and is pronounced as [ˈbɛmɪ].

## Contents

* [Overview](#overview)
* [Code example](#code-example)
* [Architecture](#architecture)
* [Usage](#usage)
  * [Workflows](#workflows)
    * [Workflow definition](#workflow-definition)
    * [Workflow validation](#workflow-validation)
    * [Workflow concurrency](#workflow-concurrency)
    * [Workflow querying](#workflow-querying)
  * [Actions](#actions)
    * [Action validation](#action-validation)
    * [Action error handling](#action-error-handling)
    * [Action rollback](#action-rollback)
    * [Action querying](#action-querying)
    * [Action concurrency](#action-concurrency)
* [Installation](#installation)
* [Alternatives](#alternatives)
* [License](#license)
* [Code of Conduct](#code-of-conduct)

## Overview

* Explicitly defined and orchestrated workflows instead of implicit execution sequences and spaghetti code
* Synchronous, scheduled, and background execution of workflows
* Improved reliability with transactions, queues, retries, timeouts, rate limiting, and priorities
* Implemented patterns like sagas, distributed tracing, transactional outbox, and railway-oriented programming
* Full visibility into the system, event logging for debugging and auditing, and monitoring with the web UI
* Simple distributed workflow execution across services, applications, and programming languages (soon)

## Code example

Here is an example of a multi-step workflow:

```ruby
# app/workflows/order_workflow.rb
class OrderWorkflow < Bemi::Workflow
  name :order

  def perform
    action :process_payment, sync: true
    action :send_confirmation, wait_for: [:process_payment], async: true
    action :ship_package, wait_for: [:process_payment], async: { queue: 'warehouse' }
    action :request_feedback, wait_for: [:ship_package], async: { delay: 7.days.to_i }
  end
end
```

To run an instance of this workflow:

```ruby
# Init a workflow, it will stop at the first action and wait until it is executed synchronously
workflow = Bemi.perform_workflow(:order, context: { order_id: params[:order_id], user_id: current_user.id })

# Process payment by running the first workflow action synchronously
Bemi.perform_action(:process_payment, workflow_id: workflow.id, input: { payment_token: params[:payment_token] })

# Once the payment is processed, the next actions in the workflow
# will be executed automatically through background workers
```

Each action can be implemented in a separate class that can be called "action", "service", "use case", "interactor", "mutation"...  you name it:

```ruby
# app/actions/order/process_payment_action.rb
class Order::ProcessPaymentAction < Bemi::Action
  name :process_payment

  def perform
    payment = PaymentProcessor.pay_for!(workflow.context[:order_id], input[:payment_token])
    { payment_id: payment.id }
  end
end
```

```ruby
# app/actions/order/send_confirmation_action.rb
class Order::SendConfirmationAction < Bemi::Action
  name :send_confirmation

  def perform
    payment_output = wait_for(:process_payment).output
    mail = OrderMailer.send_confirmation(payment_output[:payment_id])
    { delivered: mail.delivered? }
  end
end
```

```ruby
# ../warehouse/app/actions/order/ship_package_action.rb
class Order::ShipPackageAction < Bemi::Action
  name :ship_package

  def perform
    # Run a separate "shipment" workflow
    shipment_workflow = Bemi.perform_workflow(:shipment, context: { order_id: workflow.context[:order_id] })
    { shipment_workflow_id: shipment_workflow.id }
  end
end
```

```ruby
# app/actions/order/request_feedback_action.rb
class Order::RequestFeedbackAction < Bemi::Action
  name :request_feedback

  def perform
    mail = OrderMailer.request_feedback(workflow.context[:user_id])
    { delivered: mail.delivered? }
  end
end
```

## Architecture

Bemi is designed to be lightweight and simple to use by default. As a system dependency, all you need is PostgreSQL.

```
         /‾‾‾\
         \___/
       __/   \__
      /   User  \
           │
 - - - - - │ - - - - - - - - - - - - - - - -
╵          │  Start "order" workflow         ╵
╵          ∨                                 ╵
╵  ________________                          ╵  [‾‾‾‾‾‾‾‾‾‾‾‾]
╵ ┆ [Rails Server] ┆  Run "process_payment"  ╵  [------------]
╵ ┆      with      ┆⸺⸺⸺⸺⸺⸺⸺⸺⸺> [ PostgreSQL ]
╵ ┆    Bemi gem    ┆  action synchronously   ╵  [------------]
╵  ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾                          ╵  [____________]
╵                                            ╵        │
╵                                            ╵        │
╵   _______________                          ╵        │
╵  | [Bemi Worker] | Run "send_confirmation" ╵        │
╵  |   "default"   | <⸺⸺⸺⸺⸺⸺⸺⸺⸺⸺⸺│
╵  |     queue     |      action async       ╵        │        - - - - - - - - - - - - - - - - - - -
╵   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾                          ╵        │       ╵                     _______________  ╵
╵                                            ╵        │       ╵ Run "ship_package" | [Bemi Worker] | ╵
╵                                            ╵        │⸺⸺⸺⸺⸺⸺⸺⸺⸺> |  "warehouse"  | ╵
╵                                            ╵        │       ╵    action async    |     queue     | ╵
╵   _______________                          ╵        │       ╵                     ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  ╵
╵  | [Bemi Worker] |  Run "request_feedback" ╵        │       ╵                                      ╵
╵  |   "default"   | <⸺⸺⸺⸺⸺⸺⸺⸺⸺⸺⸺╵       ╵                                      ╵
╵  |     queue     |    action by schedule   ╵                ╵                                      ╵
╵   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾                          ╵                ╵                                      ╵
╵                                            ╵                ╵                                      ╵
╵              Store service                 ╵                ╵          Warehouse service           ╵
 - - - - - - - - - - - - - - - - - - - - - -                   - - - - - - - - - - - - - - - - - - - -
```

* Workflows

Bemi orchestrates workflows by persisting their execution state into PostgreSQL. When connecting to PostgreSQL, Bemi first scans the codebase and registers all workflows uniquely identified by `name`. Workflows describe a sequence of actions by using the DSL written in Ruby that can be run synchronously in the same process or asynchronously and by schedule in workers.

* Actions

Actions are also uniquely identified by `name`. They can receive data from an input if ran synchronously, previously executed actions if they depend on them, and the shared workflow execution context. They can be implemented and executed in any service or application as long as it is connected to the same PostgreSQL instance. So, there is no need to deal with message passing by implementing APIs, callbacks, message buses, data serialization, etc.

* Workers

Bemi workers allow running actions that are executed asynchronously or by schedule. One worker represents a process with multiple threads to enable concurrency. Workers can process one or more `queues` and execute different actions across different workflows simultaneously if they are assigned to the same workers' queues.

See the [Alternatives](#alternatives) section that describes how Bemi is different from other tools you might be familiar with.

## Usage

### Workflows

#### Workflow definition

Workflows declaratively describe actions that can be executed

* Synchronously

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration

  def perform
    action :create_user, sync: true
    action :send_confirmation_email, sync: true
    action :confirm_email_address, sync: true
  end
end

workflow = Bemi.perform_workflow(:registration, context: { email: params[:email] })
Bemi.perform_action(:create_user, workflow_id: workflow.id, input: { password: params[:password] })
Bemi.perform_action(:send_confirmation_email, workflow_id: workflow.id)
Bemi.perform_action(:confirm_email_address, workflow_id: workflow.id, input: { token: params[:token] })
```

* Asynchronously

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration

  def perform
    action :create_user, async: true
    action :send_welcome_email, wait_for: [:create_user], async: true
    action :run_background_check, wait_for: [:send_welcome_email], async: { queue: 'kyc' }
  end
end

Bemi.perform_workflow(:registration, context: { email: params[:email] })
```

* By schedule

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration

  def perform
    action :create_user, async: { cron: '0 2 * * *' } # daily at 2am
    action :send_welcome_email, async: { cron: '0 3 * * *', queue: 'emails', priority: 10 }
    action :run_background_check, async: { delay: 24.hours.to_i },
  end
end

Bemi.perform_workflow(:registration, context: { email: params[:email] })
```

#### Workflow validation

Workflow can define the shape of the `context` and validate it against a JSON Schema

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration
  context_schema {
    type: :object,
    properties: { email: { type: :string } },
    required: [:email],
  }
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
# => Bemi::ConcurrencyError: cannot run more than 1 'registration' workflow at the same time
```

#### Workflow querying

You can query workflows if, for example, one of the actions in the middle of the workflow execution needs to be triggered manually

```ruby
workflow = Bemi.find_workflow(:registration, context: { email: 'email@example.com' })

workflow.canceled?
workflow.completed?
workflow.failed?
workflow.running?
workflow.timed_out?

# Persisted and deserialized from JSON
workflow.context

Bemi.perform_action(:confirm_email_address, workflow_id: workflow.id)
```

### Actions

#### Action validation

Bemi allows to define the shape of actions' inputs and outputs and validate it against a JSON Schema

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration

  def perform
    action :create_user,
      sync: true,
      input_schema: {
        type: :object, properties: { password: { type: :string } }, required: [:password],
      },
      output_schema: {
        type: :object, properties: { user_id: { type: :integer } }, required: [:user_id],
      }
  end
end
```

#### Action error handling

Custom `retry` count

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration

  def perform
    action :create_user, async: true, on_error: { retry: :exponential_backoff } # default retry option
    action :send_welcome_email, async: true, on_error: { retry: 1 }
  end
end
```

Custom error handler with `around_perform`

```ruby
class Registration::SendWelcomeEmailAction < Bemi::Action
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
    add_error!(:email, "Invalid email: #{context[:email]}")
    fail! # don't retry if there is an application-level error
  rescue Errno::ECONNRESET => e
    raise e # retry by raising an exception if there is a temporary system-level error
  end
end
```

#### Action rollback

If one of the actions in a workflow fails, all previously executed actions can be rolled back by defining a method called `rollback`

```ruby
class Order::ProcessPaymentAction < Bemi::Action
  name :process_payment
  around_rollback :rollback_notifier

  def perform
    payment = PaymentProcessor.pay_for!(workflow.context[:order_id], input[:payment_token])
    { payment_id: payment.id }
  end

  def rollback
    refund = PaymentProcessor.issue_refund!(output[:payment_id], input[:payment_token])
    { refund_id: refund.id }
  end

  def rollback_notifier(&block)
    OrderMailer.notify_cancelation(output[:payment_id])
    block.call
  end
end
```

#### Action querying

```ruby
workflow = Bemi.find_workflow(:registration, context: { email: 'email@example.com' })
action = Bemi.find_action(:create_user, workflow_id: workflow.id)

action.canceled?
action.completed?
action.failed?
action.running?
action.timed_out?

action.workflow
action.options

# Persisted and deserialized from JSON
action.input
action.output
action.errors
action.rollback_output
action.context
```

#### Action concurrency

Custom concurrency `limit`

```ruby
class RegistrationWorkflow < Bemi::Workflow
  name :registration

  def perform
    action :create_user, async: true, concurrency: { limit: 1, on_conflict: :reschedule } # or :raise
  end
end
```

Custom uniqueness key defined in `concurrency_key`

```ruby
class Registration::SendWelcomeEmailAction < Bemi::Action
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

## Installation

Add this line to your application's Gemfile:

```
gem 'bemi'
```

And then execute:

```
$ bundle install
```

Or install it yourself as:

```
$ gem install bemi
```

## Alternatives

#### Background jobs with persistent state

Tools like Sidekiq, Que, and GoodJob are similar since they execute jobs in background, persist the execution state, retry, etc. These tools, however, focus on executing a single job as a unit of work. Bemi can be used in a similar way to perform single actions. But it shines when it comes to managing chains of actions defined in workflows without a need to use complex callbacks.

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

Temporal was born based on challenges faced by big-tech and enterprise companies. As a result, it has a complex architecture with deployed clusters, different databases like Cassandra and optional Elasticsearch, and multiple services for frontend, matching, history, etc. It was initially designed for programming languages like Java and Go. Some would argue that the development and user experience are quite rough. Plus, at the time of this writing, it doesn't have an official stable SDK for our favorite programming language (Ruby).

AWS Step Functions rely on using AWS Lambda to execute each action in a workflow. For various reasons, not everyone can use AWS and their serverless solution. Additionally, workflows should be defined in JSON by using Amazon States Language instead of using a regular programming language.

Argo Workflows relies on using Kubernetes. It is closer to infrastructure-level workflows since it relies on running a container for each workflow action and doesn't provide code-level features. Additionally, it requires defining workflows in YAML.

Airflow is a popular tool for data engineering pipelines. Unfortunately, it can work only with Python.

#### Ruby frameworks for writing better code

There are many libraries that also implement useful patterns and allow better organize the code. For example, Interactor, ActiveInteraction, Mutations, Dry-Rb, and Trailblazer. They, however, don't help with asynchronous and distributed execution with better reliability guarantees that many of us rely on to execute code "out-of-band" to avoid running long-running workflows in a request/response lifecycle. For example, when sending emails, sending requests to other services, running multiple actions in parallel, etc.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Bemi project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/exAspArk/bemi/blob/master/CODE_OF_CONDUCT.md).
