Rx = require 'rx-lite'
_ = require 'underscore'
Category = require '../flux/models/category'
QuerySubscriptionPool = require '../flux/models/query-subscription-pool'
DatabaseStore = require '../flux/stores/database-store'

CategoryOperators =
  sort: ->
    obs = @.map (categories) ->
      return categories.sort (catA, catB) ->
        nameA = catA.displayName
        nameB = catB.displayName

        # Categories that begin with [, like [Mailbox]/For Later
        # should appear at the bottom, because they're likely autogenerated.
        nameA = "ZZZ"+nameA if nameA[0] is '['
        nameB = "ZZZ"+nameB if nameB[0] is '['

        nameA.localeCompare(nameB)
    _.extend(obs, CategoryOperators)

  categoryFilter: (filter) ->
    obs = @.map (categories) ->
      return categories.filter filter
    _.extend(obs, CategoryOperators)

CategoryObservables =

  forAllAccounts: =>
    observable = Rx.Observable.fromQuery(DatabaseStore.findAll(Category))
    _.extend(observable, CategoryOperators)
    observable

  forAccount: (account) =>
    if account
      observable = Rx.Observable.fromQuery(DatabaseStore.findAll(Category).where(accountId: account.id))
    else
      observable = Rx.Observable.fromQuery(DatabaseStore.findAll(Category))
    _.extend(observable, CategoryOperators)
    observable

  standard: (account) =>
    observable = Rx.Observable.fromConfig('core.workspace.showImportant')
      .flatMapLatest (showImportant) =>
        return CategoryObservables.forAccount(account).sort()
          .categoryFilter (cat) -> cat.isStandardCategory(showImportant)
    _.extend(observable, CategoryOperators)
    observable

  user: (account) =>
    CategoryObservables.forAccount(account).sort()
      .categoryFilter (cat) -> cat.isUserCategory()

  hidden: (account) =>
    CategoryObservables.forAccount(account).sort()
      .categoryFilter (cat) -> cat.isHiddenCategory()

module.exports =
  Categories: CategoryObservables

# Attach a few global helpers

Rx.Observable.fromStore = (store) =>
  return Rx.Observable.create (observer) =>
    unsubscribe = store.listen =>
      observer.onNext(store)
    observer.onNext(store)
    return Rx.Disposable.create(unsubscribe)

Rx.Observable.fromConfig = (configKey) =>
  return Rx.Observable.create (observer) =>
    disposable = NylasEnv.config.onDidChange configKey, =>
      observer.onNext(NylasEnv.config.get(configKey))
    observer.onNext(NylasEnv.config.get(configKey))
    return Rx.Disposable.create(disposable.dispose)

Rx.Observable.fromAction = (action) =>
  return Rx.Observable.create (observer) =>
    unsubscribe = action.listen (args...) =>
      observer.onNext(args...)
    return Rx.Disposable.create(unsubscribe)

Rx.Observable.fromQuery = (query) =>
  return Rx.Observable.create (observer) =>
    unsubscribe = QuerySubscriptionPool.add query, (result) =>
      observer.onNext(result)
    return Rx.Disposable.create(unsubscribe)

Rx.Observable.fromNamedQuerySubscription = (name, subscription) =>
  return Rx.Observable.create (observer) =>
    unsubscribe = QuerySubscriptionPool.addPrivateSubscription name, subscription, (result) =>
      observer.onNext(result)
    return Rx.Disposable.create(unsubscribe)
